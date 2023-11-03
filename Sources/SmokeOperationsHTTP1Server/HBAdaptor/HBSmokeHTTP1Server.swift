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
import HummingbirdCore
import Logging
import NIO
import NIOExtras
import NIOHTTP1
import ServiceLifecycle
import SmokeHTTP1
import SmokeInvocation

/**
 Wraps a `HummingbirdCore.HBHTTPServer` as a `ServiceLifecycle.Service`
 */
internal actor HBSmokeHTTP1Server<HBHTTPResponderType: HBHTTPResponder>: ServiceLifecycle.Service, CustomStringConvertible {
    let description = "HBSmokeHTTP1Server"
    
    let server: HBHTTPServer
    let port: Int
    let responder: HBHTTPResponderType
    let defaultLogger: Logger

    enum State {
        case initialized
        case running
        case shuttingDown
        case shutDown
    }

    private var serverState: State = .initialized

    /**
     Initializer.

     - Parameters:
        - responder: the HBHTTPResponder to handle incoming requests.
        - port: Optionally the localhost port for the server to listen on.
                If not specified, defaults to 8080.
        - defaultLogger: The logger to use for server events.
        - eventLoopGroup: The EventLoopGroup to use for the server
        - shutdownOnSignals: Specifies if the server should be shutdown when one of the given signals is received.
                            If not specified, the server will be shutdown if a SIGINT is received.
     */
    internal init(responder: HBHTTPResponderType,
                  port: Int = ServerDefaults.defaultPort,
                  defaultLogger: Logger = Logger(label: "com.amazon.SmokeFramework.SmokeHTTP1.HBSmokeHTTP1Server"),
                  eventLoopGroup: EventLoopGroup) {
        self.port = port
        self.responder = responder
        self.defaultLogger = defaultLogger

        self.server = HBHTTPServer(
            group: eventLoopGroup,
            configuration: .init(address: .hostname(ServerDefaults.defaultHost, port: port)))
    }

    private enum LifecycleCommand {
        case shutdown
    }

    func run() async throws {
        let (lifecycleEventStream, lifecycleEventContinuation) = AsyncStream.makeStream(of: LifecycleCommand.self)

        try await withGracefulShutdownHandler {
            self.defaultLogger.info("SmokeHTTP1Server (hummingbird-core) starting.",
                                    metadata: ["port": "\(self.port)"])

            try await self.server.start(responder: self.responder).get()
            self.serverState = .running
            self.defaultLogger.info("SmokeHTTP1Server (hummingbird-core) started.",
                                    metadata: ["port": "\(self.port)"])

            // suspend until the request to shutdown
            await suspendUntilShutdown(lifecycleEventStream: lifecycleEventStream)

            self.serverState = .shuttingDown
            try await self.server.stop().get()

            self.serverState = .shutDown
            self.defaultLogger.info("SmokeHTTP1Server (hummingbird-core) shutdown.")
        } onGracefulShutdown: {
            lifecycleEventContinuation.yield(.shutdown)
        }
    }

    private func suspendUntilShutdown(lifecycleEventStream: AsyncStream<LifecycleCommand>) async {
        // suspend until the request to shutdown
        for await lifecycleEvent in lifecycleEventStream {
            switch lifecycleEvent {
                case .shutdown:
                    // begin the shutdown process
                    return
            }
        }
    }
}

#if swift(<5.9.0)
    // This extension is provided with Swift 5.9 and greater
    fileprivate extension AsyncStream {
        static func makeStream(of _: Element.Type = Element.self,
                               bufferingPolicy limit: Continuation
                                   .BufferingPolicy = .unbounded) -> (stream: AsyncStream<Element>, continuation: AsyncStream<Element>.Continuation) {
            var continuation: AsyncStream<Element>.Continuation!
            let stream = AsyncStream<Element>(bufferingPolicy: limit) { continuation = $0 }
            return (stream: stream, continuation: continuation!)
        }
    }
#endif
