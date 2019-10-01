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
// SmokeHTTP1Server+startAsOperationServer.swift
// SmokeOperationsHTTP1
//
import Foundation
import SmokeHTTP1
import NIOHTTP1
import LoggerAPI
import SmokeOperations

public extension SmokeHTTP1Server {
    
    /**
     Creates and starts a SmokeHTTP1Server to handle operations using the
     provided handlerSelector. This call will return once the server has started.
     
     - Parameters:
         - handlerSelector: the selector that will provide an operation
                            handler for a operation request
         - context: the context to pass to operation handlers.
         - port: Optionally the localhost port for the server to listen on.
                 If not specified, defaults to 8080.
         - invocationStrategy: Optionally the invocation strategy for incoming requests.
                               If not specified, the handler for incoming requests will
                               be invoked on DispatchQueue.global().
         - eventLoopProvider: Provides the event loop to be used by the server.
                              If not specified, the server will create a new multi-threaded event loop
                              with the number of threads specified by `System.coreCount`.
     - Returns: the SmokeHTTP1Server that was created and started.
     */
    static func startAsOperationServer<ContextType, SelectorType>(
        withHandlerSelector handlerSelector: SelectorType,
        andContext context: ContextType,
        andPort port: Int = ServerDefaults.defaultPort,
        invocationStrategy: InvocationStrategy = GlobalDispatchQueueAsyncInvocationStrategy(),
        eventLoopProvider: EventLoopProvider = .spawnNewThreads) throws -> SmokeHTTP1Server
        where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ContextType,
        SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
        SelectorType.DefaultOperationDelegateType.ResponseHandlerType == HTTP1ResponseHandler {
            let handler = OperationServerHTTP1RequestHandler(
                handlerSelector: handlerSelector,
                context: context)
            let server = SmokeHTTP1Server(handler: handler,
                                          port: port,
                                          invocationStrategy: invocationStrategy,
                                          eventLoopProvider: eventLoopProvider)
            
            try server.start()
            
            return server
    }
}
