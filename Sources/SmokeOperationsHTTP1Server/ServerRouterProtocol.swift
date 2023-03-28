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
//  ServerRouterProtocol.swift
//  SmokeOperationsHTTP1Server
//

import SmokeOperations
import NIOHTTP1
import SwiftMiddleware
import SmokeAsyncHTTP1Server
import SmokeHTTP1ServerMiddleware
import SmokeOperationsHTTP1

public protocol ServerRouterProtocol<OuterMiddlewareContext, InnerMiddlewareContext, OperationIdentifer> {
    associatedtype OuterMiddlewareContext: ContextWithMutableLogger & ContextWithMutableRequestId
    associatedtype InnerMiddlewareContext: ContextWithPathShape & ContextWithMutableLogger
        & ContextWithHTTPServerRequestHead & ContextWithMutableRequestId
    associatedtype OperationIdentifer: OperationIdentity
    
    init()

    func handle(_ input: HTTPServerRequest, context: OuterMiddlewareContext) async throws -> HTTPServerResponse
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - handler: the handler to add.
     */
    mutating func addHandlerForOperation(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        handler: @escaping @Sendable (HTTPServerRequest, InnerMiddlewareContext) async throws -> HTTPServerResponse)
}

public extension ServerRouterProtocol {
    mutating func addHandlerForOperation<ApplicationContext, MiddlewareType: TransformMiddlewareProtocol>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            middlewareStack: MiddlewareType,
            operation: @escaping @Sendable (MiddlewareType.TransformedInput, ApplicationContext) async throws -> MiddlewareType.OriginalOutput,
            applicationContextProvider: @escaping @Sendable (HTTPServerRequestContext<OperationIdentifer>) -> ApplicationContext)
    where MiddlewareType.TransformedOutput == HTTPServerResponse,
          MiddlewareType.OriginalInput == HTTPServerRequest,
          MiddlewareType.Context == InnerMiddlewareContext {
        @Sendable func next(input: MiddlewareType.TransformedInput, middlewareContext: InnerMiddlewareContext) async throws
        -> MiddlewareType.OriginalOutput {
            let requestContext = HTTPServerRequestContext(logger: middlewareContext.logger,
                                                          requestId: middlewareContext.internalRequestId,
                                                          requestHead: middlewareContext.httpServerRequestHead,
                                                          operationIdentifer: operationIdentifer)
            let applicationContext = applicationContextProvider(requestContext)
            return try await operation(input, applicationContext)
        }
        
        @Sendable func handler(request: HTTPServerRequest, middlewareContext: InnerMiddlewareContext) async throws -> HTTPServerResponse {
            return try await middlewareStack.handle(request, context: middlewareContext, next: next)
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
}
