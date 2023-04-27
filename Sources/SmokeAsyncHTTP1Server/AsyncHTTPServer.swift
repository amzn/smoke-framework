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
// AsyncHTTPServer.swift
// SmokeAsyncHTTP1Server
//

import Foundation
@_spi(AsyncChannel) import NIOCore
import NIOHTTP1
@_spi(AsyncChannel) import NIOPosix
import NIOExtras
import Logging
import ServiceLifecycle

public struct ServerDefaults {
    static let defaultHost = "0.0.0.0"
    public static let defaultPort = 8080
}

/**
 A basic non-blocking HTTP server that handles a request with an
 optional body and returns a response with an optional body.
 */
public struct AsyncHTTPServer: ServiceLifecycle.Service, CustomStringConvertible {
    @_spi(AsyncChannel) public typealias AsyncServerChannel =
        NIOAsyncChannel<NIOAsyncChannel<HTTPServerRequestPart, AsyncHTTPServerResponsePart>, Never>
    
    public var description: String = "AsyncHTTPServer"
    
    let port: Int
    
    let handler: @Sendable (HTTPServerRequest) async -> HTTPServerResponse
    let defaultLogger: Logger
    
    let eventLoopGroup: EventLoopGroup
    
    /**
     Initializer.
 
     - Parameters:
        - handler: the HTTPRequestHandler to handle incoming requests.
        - port: Optionally the localhost port for the server to listen on.
                If not specified, defaults to 8080.
        - eventLoopGroup: The event loop to be used by the server.
     */
    public init(handler: @Sendable @escaping (HTTPServerRequest) async -> HTTPServerResponse,
                port: Int = ServerDefaults.defaultPort,
                defaultLogger: Logger = Logger(label: "com.amazon.SmokeFramework.SmokeAsyncHTTPServer.AsyncHTTPServer"),
                eventLoopGroup: EventLoopGroup) {
        self.port = port
        self.handler = handler
        self.defaultLogger = defaultLogger
        self.eventLoopGroup = eventLoopGroup
    }
    
    private enum RequestStreamCommand: Sendable {
        case process(@Sendable () async -> ())
        case shutdown
    }
    
    public func run() async throws {
        // quiesce open channels
        let (quiesce, asyncChannel) = try await self.start()
        let shutdownPromise = asyncChannel.channel.eventLoop.makePromise(of: Void.self)
        
        try await withGracefulShutdownHandler {
#if os(Linux)
            // A `DiscardingTaskGroup` will discard results of its child tasks immediately and
            // release the child task that produced the result.
            // This allows for efficient and "running forever" request accepting loops.
            try await withThrowingDiscardingTaskGroup { group in
                for try await inboundStream in asyncChannel.inboundStream {
                    let manager = AsyncHTTP1RequestResponseManager(handler: self.handler)
                    
                    group.addTask {
                        await manager.process(asyncChannel: inboundStream)
                    }
                }
            }
#else
            // DiscardingTaskGroup are not available under MacOS for Swift 5.8.
            for try await inboundStream in asyncChannel.inboundStream {
                let manager = AsyncHTTP1RequestResponseManager(handler: self.handler)
                
                Task {
                    await manager.process(asyncChannel: inboundStream)
                }
            }
#endif
        } onGracefulShutdown: {
            self.shutdownGracefully(asyncChannel: asyncChannel, quiesce: quiesce, shutdownPromise: shutdownPromise)
        }
        
        try await shutdownPromise.futureResult.get()
        
        self.defaultLogger.info("AsyncHTTPServer shutdown.")
    }
    
    private func start() async throws
    -> (ServerQuiescingHelper, AsyncServerChannel) {
        let quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
        
        defaultLogger.info("AsyncHTTPServer starting.",
                           metadata: ["port": "\(self.port)"])
        
        // create a ServerBootstrap with a HTTP Server pipeline that delegates
        // to a HTTPChannelInboundHandler
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPServerResponsePartConverterHandler())
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
                
        let asyncChannel: AsyncServerChannel = try await bootstrap.asyncBind(
            host: ServerDefaults.defaultHost, port: port)
        defaultLogger.info("AsyncHTTPServer started.",
                           metadata: ["port": "\(self.port)"])
        
        return (quiesce, asyncChannel)
    }
    
    @_spi(AsyncChannel) public func shutdownGracefully(asyncChannel: AsyncServerChannel,
                                                       quiesce: ServerQuiescingHelper,
                                                       shutdownPromise: EventLoopPromise<Void>) {
        // quiesce open channels
        quiesce.initiateShutdown(promise: shutdownPromise)
    }
}

extension ServerBootstrap {
    func asyncBind<ChildChannelInboundIn: Sendable, ChildChannelOutboundOut: Sendable>(
        host: String,
        port: Int
    ) async throws -> NIOAsyncChannel<NIOAsyncChannel<ChildChannelInboundIn, ChildChannelOutboundOut>, Never> {
        try await self.bind(host: host, port: port)
    }
}
