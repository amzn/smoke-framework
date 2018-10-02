// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

public struct ServerDefaults {
    static let defaultHost = "0.0.0.0"
    public static let defaultPort = 8080
    public static let defaultServerThreads = 6
}

/**
 A basic non-blocking HTTP server that handles a request with an
 optional body and returns a response with an optional body.
 */
public class SmokeHTTP1Server {
    let port: Int
    let serverThreads: Int
    
    let group: MultiThreadedEventLoopGroup
    let threadPool: BlockingIOThreadPool
    let handler: HTTP1RequestHandler
    var channel: Channel?
    
    /**
     Initializer.
 
    - Parameters:
        - handler: the HTTPRequestHandler to handle incoming requests.
        - port: Optionally the localhost port for the server to listen on.
        - serverThreads: Optionally the number of threads to use for responding
          to requests.
     */
    public init(handler: HTTP1RequestHandler,
                port: Int = ServerDefaults.defaultPort,
                serverThreads: Int = ServerDefaults.defaultServerThreads) {
        self.port = port
        self.serverThreads = serverThreads
        self.handler = handler
        
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.threadPool = BlockingIOThreadPool(numberOfThreads: serverThreads)
    }
    
    /**
     Starts the server on the provided port. Function returns
     when the server is started.
     */
    public func start() throws {
        threadPool.start()
        
        let currentHandler = handler
        
        // create a ServerBootstrap with a HTTP Server pipeline that delegates
        // to a HTTPChannelInboundHandler
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().then {
                    channel.pipeline.add(handler: HTTP1ChannelInboundHandler(handler: currentHandler))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        channel = try bootstrap.bind(host: ServerDefaults.defaultHost, port: port).wait()
    }
    
    /**
     Stops the server.
     */
    public func stop() throws {
        try group.syncShutdownGracefully()
        try threadPool.syncShutdownGracefully()
    }
    
    /**
     Blocks until the server has been shut down.
     */
    public func wait() throws {
        try channel?.closeFuture.wait()
    }
}
