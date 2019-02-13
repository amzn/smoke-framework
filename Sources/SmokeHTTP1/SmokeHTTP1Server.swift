// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeHTTP1Server.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import NIOExtras
import LoggerAPI

public struct ServerDefaults {
    static let defaultHost = "0.0.0.0"
    public static let defaultPort = 8080
}

/**
 A basic non-blocking HTTP server that handles a request with an
 optional body and returns a response with an optional body.
 */
public class SmokeHTTP1Server {
    let port: Int
    
    let group: MultiThreadedEventLoopGroup
    let quiesce: ServerQuiescingHelper
    let signalSource: DispatchSourceSignal
    let fullyShutdownPromise: EventLoopPromise<Void>
    let handler: HTTP1RequestHandler
    let invocationStrategy: InvocationStrategy
    var channel: Channel?
    
    /**
     Initializer.
 
    - Parameters:
        - handler: the HTTPRequestHandler to handle incoming requests.
        - port: Optionally the localhost port for the server to listen on.
        - invocationStrategy: Optionally the invocation strategy for incoming requests.
                              If not specified, the handler for incoming requests will be invoked on DispatchQueue.global().
     */
    public init(handler: HTTP1RequestHandler,
                port: Int = ServerDefaults.defaultPort,
                invocationStrategy: InvocationStrategy = GlobalDispatchQueueInvocationStrategy()) {
        let signalQueue = DispatchQueue(label: "io.smokeframework.SmokeHTTP1Server.SignalHandlingQueue")
        
        self.port = port
        self.handler = handler
        self.invocationStrategy = invocationStrategy
        
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.quiesce = ServerQuiescingHelper(group: group)
        self.fullyShutdownPromise = group.next().newPromise()
        self.signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: signalQueue)
        
        signalSource.setEventHandler { [unowned self] in
            self.signalSource.cancel()
            Log.verbose("Received signal, initiating shutdown which should complete after the last request finished.")

            self.quiesce.initiateShutdown(promise: self.fullyShutdownPromise)
        }
        signal(SIGINT, SIG_IGN)
        signalSource.resume()
    }
    
    /**
     Starts the server on the provided port. Function returns
     when the server is started. The server will continue running until
     either shutdown() is called or the surrounding application is being terminated.
     */
    public func start() throws {
        let currentHandler = handler
        let currentInvocationStrategy = invocationStrategy
        
        // create a ServerBootstrap with a HTTP Server pipeline that delegates
        // to a HTTPChannelInboundHandler
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .serverChannelInitializer { [unowned self] channel in
                channel.pipeline.add(handler: self.quiesce.makeServerChannelHandler(channel: channel))
            }
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().then {
                    channel.pipeline.add(handler: HTTP1ChannelInboundHandler(
                        handler: currentHandler,
                        invocationStrategy: currentInvocationStrategy))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        channel = try bootstrap.bind(host: ServerDefaults.defaultHost, port: port).wait()
        
        fullyShutdownPromise.futureResult.whenComplete { [unowned self] in
            do {
                try self.group.syncShutdownGracefully()
            } catch {
                Log.error("Server unable to shutdown cleanly following full shutdown.")
            }
        }
    }
    
    /**
     Starts the process of shutting down the server.
     */
    public func shutdown() throws {
        quiesce.initiateShutdown(promise: nil)
    }
    
    /**
     Blocks until the server has been shut down.
     */
    public func waitUntilShutdown() throws {
        try fullyShutdownPromise.futureResult.wait()
    }
    
    /**
     Blocks until the server has been shut down.
     */
    public func waitUntilShutdownAndThen(onShutdown: @escaping () -> Void) throws {
        fullyShutdownPromise.futureResult.whenComplete(onShutdown)
        
        try fullyShutdownPromise.futureResult.wait()
    }
}
