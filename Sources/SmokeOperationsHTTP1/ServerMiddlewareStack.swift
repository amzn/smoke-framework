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
//  ServerMiddlewareStack.swift
//  SmokeOperationsHTTP1
//

import SwiftMiddleware
import NIOHTTP1
import SmokeOperations
import SmokeAsyncHTTP1Server

public struct ServerMiddlewareStack<RouterType: ServerRouterProtocol, ApplicationContext>: ServerMiddlewareStackProtocol {
    public typealias OperationIdentifer = RouterType.OperationIdentifer
    private var router: RouterType
    
    private let initialMiddlewareContext: RouterType.OuterMiddlewareContext
    private let applicationContextProvider: @Sendable (HTTPServerRequestContext<OperationIdentifer>) -> ApplicationContext
    private let unhandledErrorTransform: JSONErrorResponseTransform<RouterType.OuterMiddlewareContext>
    
    public init(router: RouterType,
                initialMiddlewareContext: RouterType.OuterMiddlewareContext,
                applicationContextProvider: @escaping @Sendable (HTTPServerRequestContext<OperationIdentifer>) -> ApplicationContext) {
        self.router = router
        self.initialMiddlewareContext = initialMiddlewareContext
        self.applicationContextProvider = applicationContextProvider
        
        self.unhandledErrorTransform = JSONErrorResponseTransform(reason: "InternalError",
                                                                  errorMessage: nil,
                                                                  status: .internalServerError)
    }
    
    @Sendable public func handle(request: HTTPServerRequest) async -> HTTPServerResponse {
        do {
            return try await self.router.handle(request, context: self.initialMiddlewareContext)
        } catch {
            return self.unhandledErrorTransform.transform(error, context: self.initialMiddlewareContext)
        }
    }
    
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                RequestTransformType: TransformProtocol, ResponseTransformType: TransformProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: OperationIdentifer, httpMethod: HTTPMethod, allowedErrors: [(ErrorType, Int)],
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContext) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        requestTransform: RequestTransformType, responseTransform: ResponseTransformType)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    RequestTransformType.Input == HTTPServerRequest, RequestTransformType.Output == InnerMiddlewareType.Input,
    ResponseTransformType.Input == InnerMiddlewareType.Output, ResponseTransformType.Output == HTTPServerResponse,
    ResponseTransformType.Context == RouterType.InnerMiddlewareContext, RequestTransformType.Context == RouterType.InnerMiddlewareContext {
        let stack = MiddlewareTransformStack(requestTransform: requestTransform, responseTransform: responseTransform) {
            if let outerMiddleware = outerMiddleware {
                outerMiddleware
            }
            
            // Add middleware to all routes prior to transformation
        } inner: {
            if let innerMiddleware = innerMiddleware {
                innerMiddleware
            }
            
            // Add middleware to all routes after to transformation
        }
        
        self.router.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod,
                                           middlewareStack: stack, operation: operation,
                                           applicationContextProvider: self.applicationContextProvider)
    }
}
