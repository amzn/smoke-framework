// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// StandardSmokeHTTP1Server.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import NIOExtras
import Logging
import SmokeInvocation

/**
 A basic non-blocking HTTP server that handles a request with an
 optional body and returns a response with an optional body.
 */
public class StandardSmokeHTTP1Server<HTTP1RequestHandlerType: HTTP1RequestHandler,
                                      InvocationContext: HTTP1RequestInvocationContext>
        where HTTP1RequestHandlerType.ResponseHandlerType == StandardHTTP1ResponseHandler<InvocationContext> {
    let port: Int
    
    let quiesce: ServerQuiescingHelper
    let signalSource: DispatchSourceSignal?
    let fullyShutdownPromise: EventLoopPromise<Void>
    let handler: HTTP1RequestHandlerType
    let invocationStrategy: InvocationStrategy
    var channel: Channel?
    let defaultLogger: Logger
    let shutdownDispatchGroup: DispatchGroup
    let shutdownCompletionHandlerInvocationStrategy: InvocationStrategy
    
    enum State {
        case initialized
        case running
        case shuttingDown
        case shutDown
    }
    private var shutdownCompletionHandlers: [() -> Void] = []
    private var serverState: State = .initialized
    private var stateLock: NSLock = NSLock()
    
    let eventLoopGroup: EventLoopGroup
    let ownEventLoopGroup: Bool
    
    /**
     Initializer.
 
     - Parameters:
        - handler: the HTTPRequestHandler to handle incoming requests.
        - port: Optionally the localhost port for the server to listen on.
                If not specified, defaults to 8080.
        - invocationStrategy: Optionally the invocation strategy for incoming requests.
                              If not specified, the handler for incoming requests will
                              be invoked on DispatchQueue.global().
        - shutdownCompletionHandlerInvocationStrategy: Optionally the invocation strategy for shutdown completion handlers.
                                                       If not specified, the shutdown completion handlers will
                                                       be invoked on DispatchQueue.global() synchronously so that callers
                                                       to `waitUntilShutdown*` will not unblock until all completion handlers
                                                       have finished.
        - eventLoopProvider: Provides the event loop to be used by the server.
                             If not specified, the server will create a new multi-threaded event loop
                             with the number of threads specified by `System.coreCount`.
        - shutdownOnSignal: Specifies if the server should be shutdown when a signal is received.
                            If not specified, the server will be shutdown if a SIGINT is received.
     */
    public init(handler: HTTP1RequestHandlerType,
                port: Int = ServerDefaults.defaultPort,
                invocationStrategy: InvocationStrategy = GlobalDispatchQueueAsyncInvocationStrategy(),
                defaultLogger: Logger = Logger(label: "com.amazon.SmokeFramework.SmokeHTTP1.SmokeHTTP1Server"),
                shutdownCompletionHandlerInvocationStrategy: InvocationStrategy = GlobalDispatchQueueSyncInvocationStrategy(),
                eventLoopProvider: SmokeHTTP1Server.EventLoopProvider = .spawnNewThreads,
                shutdownOnSignal: SmokeHTTP1Server.ShutdownOnSignal = .sigint) {
        let signalQueue = DispatchQueue(label: "io.smokeframework.SmokeHTTP1Server.SignalHandlingQueue")
        
        self.port = port
        self.handler = handler
        self.defaultLogger = defaultLogger
        self.invocationStrategy = invocationStrategy
        self.shutdownCompletionHandlerInvocationStrategy = shutdownCompletionHandlerInvocationStrategy
        
        switch eventLoopProvider {
        case .spawnNewThreads:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            self.ownEventLoopGroup = true
        case .use(let existingEventLoopGroup):
            self.eventLoopGroup = existingEventLoopGroup
            self.ownEventLoopGroup = false
        }
        
        let newSignalSource: (DispatchSourceSignal, Int32)?
        switch shutdownOnSignal {
        case .none:
           newSignalSource = nil
        case .sigint:
            newSignalSource = (DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue), SIGINT)
        case .sigterm:
            newSignalSource = (DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue), SIGTERM)
        }
        
        self.quiesce = ServerQuiescingHelper(group: eventLoopGroup)
        self.fullyShutdownPromise = eventLoopGroup.next().makePromise()
        self.signalSource = newSignalSource?.0
        self.shutdownDispatchGroup = DispatchGroup()
        // enter the DispatchGroup during initialization so waiting for the
        // shutdown of an initalized or started server will wait
        shutdownDispatchGroup.enter()
        
        if let (newSignalSource, signalValue) = newSignalSource {
            newSignalSource.setEventHandler { [unowned self] in
                self.signalSource?.cancel()
                defaultLogger.error("Received signal, initiating shutdown which should complete after the last request finished.")

                do {
                    try self.shutdown()
                } catch {
                    defaultLogger.error("Unable to shutdown server on signalSource: \(error)")
                }
            }
            signal(signalValue, SIG_IGN)
            newSignalSource.resume()
        }
    }
    
    /**
     Starts the server on the provided port. Function returns
     when the server is started. The server will continue running until
     either shutdown() is called or the surrounding application is being terminated.
     */
    public func start() throws {
        defaultLogger.info("SmokeHTTP1Server starting on port \(port).")
        
        guard updateOnStart() else {
            // nothing to do; already started
            return
        }
        
        let currentHandler = handler
        let currentInvocationStrategy = invocationStrategy
        
        // create a ServerBootstrap with a HTTP Server pipeline that delegates
        // to a HTTPChannelInboundHandler
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .serverChannelInitializer { [unowned self] channel in
                channel.pipeline.addHandler(self.quiesce.makeServerChannelHandler(channel: channel))
            }
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTP1ChannelInboundHandler<HTTP1RequestHandlerType,
                                                    HTTP1RequestHandlerType.ResponseHandlerType.InvocationContext>(
                        handler: currentHandler,
                        invocationStrategy: currentInvocationStrategy))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        channel = try bootstrap.bind(host: ServerDefaults.defaultHost, port: port).wait()
        
        fullyShutdownPromise.futureResult.whenComplete { [unowned self] _ in
            do {
                let shutdownCompletionHandlers = self.updateStateOnShutdownComplete()
                
                // execute all the completion handlers
                shutdownCompletionHandlers.forEach { self.shutdownCompletionHandlerInvocationStrategy.invoke(handler: $0) }
                
                if self.ownEventLoopGroup {
                    try self.eventLoopGroup.syncShutdownGracefully()
                }
                
                // release any waiters for shutdown
                self.shutdownDispatchGroup.leave()
            } catch {
                self.defaultLogger.error("Server unable to shutdown cleanly following full shutdown.")
            }
            
            self.defaultLogger.info("SmokeHTTP1Server shutdown.")
        }
        
        defaultLogger.info("SmokeHTTP1Server started on port \(port).")
    }
    
    /**
     Initiates the process of shutting down the server.
     */
    public func shutdown() throws {
        let doShutdownServer = try updateOnShutdownStart()
        
        if doShutdownServer {
            quiesce.initiateShutdown(promise: fullyShutdownPromise)
        }
    }
    
    /**
     Blocks until the server has been shutdown and all completion handlers
     have been executed.
     */
    public func waitUntilShutdown() throws {
        if !isShutdown() {
            shutdownDispatchGroup.wait()
        }
    }
    
    /**
     Blocks until the server has been shutdown and all completion handlers
     have been executed. The provided closure will be added to the list of
     completion handlers to be executed on shutdown. If the server is already
     shutdown, the provided closure will be immediately executed.
     
     - Parameters:
        - onShutdown: the closure to be executed after the server has been
                      fully shutdown.
     */
    public func waitUntilShutdownAndThen(onShutdown: @escaping () -> Void) throws {
        let handlerQueuedForFutureShutdownComplete = addShutdownHandler(onShutdown: onShutdown)
        
        if handlerQueuedForFutureShutdownComplete {
            shutdownDispatchGroup.wait()
        } else {
            // the server is already shutdown, immediately call the handler
            shutdownCompletionHandlerInvocationStrategy.invoke(handler: onShutdown)
        }
    }
    
    /**
     Provides a closure to be executed after the server has been fully shutdown.
     
     - Parameters:
        - onShutdown: the closure to be executed after the server has been
                      fully shutdown.
     */
    public func onShutdown(onShutdown: @escaping () -> Void) throws {
        let handlerQueuedForFutureShutdownComplete = addShutdownHandler(onShutdown: onShutdown)
        
        if !handlerQueuedForFutureShutdownComplete {
            // the server is already shutdown, immediately call the handler
            shutdownCompletionHandlerInvocationStrategy.invoke(handler: onShutdown)
        }
    }
    
    /**
     Updates the Lifecycle state on a start request.

     - Returns: if the start request should be acted upon (and the server started).
                Will be false if the server is already running, shutting down or has completed shutting down.
     */
    private func updateOnStart() -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        if case .initialized = serverState {
            serverState = .running
            
            return true
        }
        
        return false
    }
    
    /**
     Updates the Lifecycle state on a shutdown request.

     - Returns: if the shutdown request should be acted upon (and the server shutdown).
                Will be false if the server is already shutting down or has completed shutting down.
     - Throws: if the server has never been started.
     */
    private func updateOnShutdownStart() throws -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        let doShutdownServer: Bool
        switch serverState {
        case .initialized:
            throw SmokeHTTP1ServerError.shutdownAttemptOnUnstartedServer
        case .running:
            serverState = .shuttingDown
            
            doShutdownServer = true
        case .shuttingDown, .shutDown:
            // nothing to do; already shutting down or shutdown
            doShutdownServer = false
        }
        
        return doShutdownServer
    }
    
    /**
     Updates the Lifecycle state on shutdown completion.

     - Returns: the list of completion handlers to execute.
     */
    private func updateStateOnShutdownComplete() -> [() -> Void] {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        guard case .shuttingDown = serverState else {
            fatalError("SmokeHTTP1ServerError shutdown completed when in expected state: \(serverState)")
        }
        
        let completionHandlers = shutdownCompletionHandlers
        shutdownCompletionHandlers = []
        serverState = .shutDown
        
        return completionHandlers
    }
    
    /**
     Adds a shutdown completion handler to be executed when server shutdown is complete.

     - Returns: if the handler has been queued for execution when server shutdown is
                complete in the future. Will be false if the server is already shutdown; in
                this case, the handler can be immediately executed.
     */
    private func addShutdownHandler(onShutdown: @escaping () -> Void) -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        let handlerQueuedForFutureShutdownComplete: Bool
        switch serverState {
        case .initialized, .running, .shuttingDown:
            shutdownCompletionHandlers.append(onShutdown)
            handlerQueuedForFutureShutdownComplete = true
        case .shutDown:
            // already shutdown; immediately call the handler
            handlerQueuedForFutureShutdownComplete = false
        }
        
        return handlerQueuedForFutureShutdownComplete
    }
    
    /**
     Indicates if the server is currently shutdown.

     - Returns: if the server is currently shutdown.
     */
    private func isShutdown() -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        if case .shutDown = serverState {
            return true
        }
        
        return false
    }
}
