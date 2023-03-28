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
//  ServerMiddlewareStackProtocol.swift
//  SmokeOperationsHTTP1
//

import SwiftMiddleware
import NIOHTTP1
import SmokeOperations
import SmokeAsyncHTTP1Server

/**
 Protocol that manages adding handlers for operations using a defined middleware stack.
 */
public protocol ServerMiddlewareStackProtocol {
    associatedtype RouterType: ServerRouterProtocol
    associatedtype ApplicationContextType
    
    @Sendable func handle(request: HTTPServerRequest) async -> HTTPServerResponse
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type
        - requestTransform: The transformation operation to transform the request into the operation's input type.
        - responseTransform: The transformation operation to transform the operation's output type into the response.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                RequestTransformType: TransformProtocol, ResponseTransformType: TransformProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod, allowedErrors: [(ErrorType, Int)],
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        requestTransform: RequestTransformType, responseTransform: ResponseTransformType)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    RequestTransformType.Input == HTTPServerRequest, RequestTransformType.Output == InnerMiddlewareType.Input,
    ResponseTransformType.Input == InnerMiddlewareType.Output, ResponseTransformType.Output == HTTPServerResponse,
    ResponseTransformType.Context == RouterType.InnerMiddlewareContext, RequestTransformType.Context == RouterType.InnerMiddlewareContext
}
