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
//  SmokeOperationsHTTP1
//

import SmokeOperations
import NIOHTTP1
import SwiftMiddleware
import SmokeAsyncHTTP1Server

public protocol ServerRouterProtocol<IncomingMiddlewareContext, RouterMiddlewareContext, OutgoingMiddlewareContext,
                                     OperationIdentifer, OutputWriter> {
    // The context type that is passed to the router
    associatedtype IncomingMiddlewareContext: ContextWithMutableLogger & ContextWithMutableRequestId
    // The context type the router produces and passes to the Middleware stack
    associatedtype RouterMiddlewareContext: ContextWithPathShape & ContextWithMutableLogger & ContextWithOperationIdentifer
        & ContextWithHTTPServerRequestHead & ContextWithMutableRequestId
    // The context type that comes out of the middleware stack for each route
    associatedtype OutgoingMiddlewareContext: ContextWithPathShape & ContextWithMutableLogger & ContextWithOperationIdentifer
        & ContextWithHTTPServerRequestHead & ContextWithMutableRequestId
    associatedtype OperationIdentifer: OperationIdentity
    associatedtype OutputWriter: HTTPServerResponseWriterProtocol
    
    init()

    func handle(_ input: HTTPServerRequest, outputWriter: OutputWriter, context: IncomingMiddlewareContext) async throws
    
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
        handler: @escaping @Sendable (HTTPServerRequest, OutputWriter, RouterMiddlewareContext) async throws -> ())
}

public extension ServerRouterProtocol {
    mutating func addHandlerForOperation<ApplicationContext, MiddlewareType: TransformingMiddlewareProtocol>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            middlewareStack: MiddlewareType,
            operation: @escaping @Sendable (MiddlewareType.OutgoingInput, ApplicationContext) async throws -> MiddlewareType.OutgoingOutputWriter.OutputType,
            applicationContextProvider: @escaping @Sendable (HTTPServerRequestContext<OperationIdentifer>) -> ApplicationContext
    )
    where
    // the middleware must have an output writer at the end that conforms to `TypedOutputWriterProtocol`
    // the `OutputType` of this writer is the type returned by `operation`
    MiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the middleware will always have an input type of `HTTPServerRequest`
    MiddlewareType.IncomingInput == HTTPServerRequest,
    // the context and output writer types going into the middleware must be the types used by the router
    MiddlewareType.IncomingContext == RouterMiddlewareContext,
    MiddlewareType.IncomingOutputWriter == OutputWriter,
    // requirements for the context coming out of the middleware
    MiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead
    {
        @Sendable func next(input: MiddlewareType.OutgoingInput, outputWriter: MiddlewareType.OutgoingOutputWriter,
                            middlewareContext: MiddlewareType.OutgoingContext) async throws {
            let requestContext = HTTPServerRequestContext(logger: middlewareContext.logger,
                                                          requestId: middlewareContext.internalRequestId,
                                                          requestHead: middlewareContext.httpServerRequestHead,
                                                          operationIdentifer: operationIdentifer,
                                                          middlewareContext: middlewareContext)
            let applicationContext = applicationContextProvider(requestContext)
            let response = try await operation(input, applicationContext)
            
            try await outputWriter.write(response)
        }
        
        @Sendable func handler(request: HTTPServerRequest, outputWriter: OutputWriter, middlewareContext: RouterMiddlewareContext) async throws {
            return try await middlewareStack.handle(request, outputWriter: outputWriter, context: middlewareContext, next: next)
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
}
