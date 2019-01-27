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
     Start the Http Server to handle operations.
     
     - Parameters:
     - handlerSelector: the selector that will provide an operation
     handler for a operation request
     - context: the context to pass to operation handlers.
     */
    public static func startAsOperationServer<ContextType, SelectorType>(
        withHandlerSelector handlerSelector: SelectorType,
        andContext context: ContextType,
        andPort port: Int = ServerDefaults.defaultPort,
        invocationStrategy: InvocationStrategy = GlobalDispatchQueueInvocationStrategy()) throws
        where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ContextType,
        SelectorType.DefaultOperationDelegateType.RequestType == SmokeHTTP1Request,
        SelectorType.DefaultOperationDelegateType.ResponseHandlerType == HTTP1ResponseHandler {
            let handler = OperationServerHTTP1RequestHandler(
                handlerSelector: handlerSelector,
                context: context)
            let server = SmokeHTTP1Server(handler: handler,
                                          port: port,
                                          invocationStrategy: invocationStrategy)
            
            Log.info("Server starting on port \(port)...")
            
            try server.start()
            
            Log.info("Server started on port \(port)...")
            
            RunLoop.current.run()
    }
}
