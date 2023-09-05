// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// HBSmokeHTTP1Server.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import NIO
import NIOHTTP1
import NIOExtras
import Logging
import SmokeInvocation
import SmokeHTTP1
import HummingbirdCore

private struct ServerShutdownDetails {
    let awaitingContinuations: [CheckedContinuation<Void, Error>]
}

/**
 A basic non-blocking HTTP server that handles a request with an
 optional body and returns a response with an optional body.
 */
public class HBSmokeHTTP1Server<HBHTTPResponderType: HBHTTPResponder> {
    let server: HBHTTPServer
    let port: Int
    let responder: HBHTTPResponderType
    let signalSources: [DispatchSourceSignal]
    let defaultLogger: Logger
    
    enum State {
        case initialized
        case running
        case shuttingDown
        case shutDown
    }
    private var shutdownWaitingContinuations: [CheckedContinuation<Void, Error>] = []
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
        - shutdownOnSignals: Specifies if the server should be shutdown when one of the given signals is received.
                            If not specified, the server will be shutdown if a SIGINT is received.
     */
    public init(responder: HBHTTPResponderType,
                port: Int = ServerDefaults.defaultPort,
                defaultLogger: Logger = Logger(label: "com.amazon.SmokeFramework.SmokeHTTP1.HBSmokeHTTP1Server"),
                eventLoopProvider: SmokeHTTP1Server.EventLoopProvider = .spawnNewThreads,
                shutdownOnSignals: [SmokeHTTP1Server.ShutdownOnSignal] = [.sigint]) {
        let signalQueue = DispatchQueue(label: "io.smokeframework.HBSmokeHTTP1Server.SignalHandlingQueue")
        
        self.port = port
        self.responder = responder
        self.defaultLogger = defaultLogger
        
        switch eventLoopProvider {
        case .spawnNewThreads:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            self.ownEventLoopGroup = true
        case .use(let existingEventLoopGroup):
            self.eventLoopGroup = existingEventLoopGroup
            self.ownEventLoopGroup = false
        }
        
        self.server = HBHTTPServer(
            group: eventLoopGroup,
            configuration: .init(address: .hostname("127.0.0.1", port: port))
        )
        
        let newSignalSources: [(DispatchSourceSignal, Int32, SmokeHTTP1Server.ShutdownOnSignal)] = shutdownOnSignals.compactMap { shutdownOnSignal in
            switch shutdownOnSignal {
            case .none:
                return nil
            case .sigint:
                return (DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue), SIGINT, .sigint)
            case .sigterm:
                return (DispatchSource.makeSignalSource(signal: SIGTERM, queue: signalQueue), SIGTERM, .sigterm)
            }
        }
    
        self.signalSources = newSignalSources.map { $0.0 }
        
        newSignalSources.forEach { (signalSource, signalValue, shutdownOnSignal) in
            signalSource.setEventHandler { [unowned self] in
                self.signalSources.forEach { $0.cancel() }
                defaultLogger.info("Received signal, initiating shutdown which should complete after the last request finished.",
                                   metadata: ["signal": "\(shutdownOnSignal)"])
                
                do {
                    try self.shutdown()
                } catch {
                    defaultLogger.error("Unable to shutdown server on signalSource.",
                                        metadata: ["cause": "\(String(describing: error))"])
                }
            }
            signal(signalValue, SIG_IGN)
            signalSource.resume()
        }
    }
    
    /**
     Starts the server on the provided port. Function returns
     when the server is started. The server will continue running until
     either shutdown() is called or the surrounding application is being terminated.
     */
    public func start() throws {
        defaultLogger.info("HBSmokeHTTP1Server starting.",
                           metadata: ["port": "\(self.port)"])
        
        guard updateOnStart() else {
            // nothing to do; already started
            return
        }
        
        try self.server.start(responder: self.responder).wait()
        defaultLogger.info("HBSmokeHTTP1Server started.",
                           metadata: ["port": "\(self.port)"])
    }
    
    /**
     Initiates the process of shutting down the server.
     */
    private func shutdown() throws {
        let doShutdownServer = try updateOnShutdownStart()
        
        if doShutdownServer {
            
            do {
                try self.server.stop().wait()
                
                let serverShutdownDetails = self.updateStateOnShutdownComplete()
                
                // resume any continuations
                serverShutdownDetails.awaitingContinuations.forEach { $0.resume(returning: ()) }
                
                if self.ownEventLoopGroup {
                    try self.eventLoopGroup.syncShutdownGracefully()
                }
            } catch {
                self.defaultLogger.error("Server unable to shutdown cleanly following full shutdown.",
                                         metadata: ["cause": "\(String(describing: error))"])
            }
            
            self.defaultLogger.info("HBSmokeHTTP1Server shutdown.")
        }
    }
    
    public func untilShutdown() async throws {
        return try await withCheckedThrowingContinuation { cont in
            if !addContinuationIfShutdown(newContinuation: cont) {
                // continuation will be resumed when the server shuts down
            } else {
                // server is already shutdown
                cont.resume(returning: ())
            }
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
    private func updateStateOnShutdownComplete() -> ServerShutdownDetails {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        guard case .shuttingDown = serverState else {
            fatalError("SmokeHTTP1ServerError shutdown completed when in expected state: \(serverState)")
        }
        
        serverState = .shutDown
        
        let waitingContinuations = self.shutdownWaitingContinuations
        self.shutdownWaitingContinuations = []
        
        return ServerShutdownDetails(awaitingContinuations: waitingContinuations)
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
    
    public func addContinuationIfShutdown(newContinuation: CheckedContinuation<Void, Error>) -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        if case .shutDown = serverState {
            return true
        }
        
        self.shutdownWaitingContinuations.append(newContinuation)
        
        return false
    }
}
