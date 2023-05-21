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
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeOperations
import SmokeHTTP1ServerMiddleware
import SmokeAsyncHTTP1Server
import SmokeOperationsHTTP1

public struct ServerMiddlewareStack<RouterType: ServerRouterProtocol, ApplicationContext>: ServerMiddlewareStackProtocol
where RouterType.OuterMiddlewareContext == SmokeMiddlewareContext {
    public typealias OperationIdentifer = RouterType.OperationIdentifer
    private var router: RouterType
    
    private let applicationContextProvider: @Sendable (HTTPServerRequestContext<OperationIdentifer>) -> ApplicationContext
    private let unhandledErrorTransform: JSONErrorResponseTransform<RouterType.OuterMiddlewareContext>
    private let serverName: String
    private let serverConfiguration: SmokeServerConfiguration<OperationIdentifer>
    
    public init(serverName: String,
                serverConfiguration: SmokeServerConfiguration<OperationIdentifer>,
                applicationContextProvider: @escaping @Sendable (HTTPServerRequestContext<OperationIdentifer>) -> ApplicationContext) {
        self.router = .init()
        self.serverName = serverName
        self.serverConfiguration = serverConfiguration
        self.applicationContextProvider = applicationContextProvider
        
        self.unhandledErrorTransform = JSONErrorResponseTransform(reason: "InternalError",
                                                                  errorMessage: nil,
                                                                  status: .internalServerError)
    }
    
    @Sendable public func handle(request: HTTPServerRequest, responseWriter: HTTPServerResponseWriter) async {
        let initialMiddlewareContext = SmokeMiddlewareContext(responseWriter: responseWriter)
        
        let middlewareStack = MiddlewareStack {
            // Add middleware outside the router (operates on Request and Response types)
            SmokePingMiddleware<RouterType.OuterMiddlewareContext>()
            SmokeTracingMiddleware<RouterType.OuterMiddlewareContext>(serverName: self.serverName)
            SmokeRequestIdMiddleware<RouterType.OuterMiddlewareContext>()
            SmokeLoggerMiddleware<RouterType.OuterMiddlewareContext>()
            JSONSmokeOperationsErrorMiddleware<RouterType.OuterMiddlewareContext>()
            JSONDecodingErrorMiddleware<RouterType.OuterMiddlewareContext>()
        }
        do {
            return try await middlewareStack.handle(request, context: initialMiddlewareContext) { (innerRequest, innerContext) in
                return try await self.router.handle(innerRequest, context: innerContext)
            }
        } catch {
            return await self.unhandledErrorTransform.transform(error, context: initialMiddlewareContext)
        }
    }
    
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                RequestTransformType: TransformProtocol, ResponseTransformType: TransformProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: OperationIdentifer, httpMethod: HTTPMethod, allowedErrors: [(ErrorType, Int)],
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        requestTransform: RequestTransformType, responseTransform: ResponseTransformType)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    RequestTransformType.Input == HTTPServerRequest, RequestTransformType.Output == InnerMiddlewareType.Input,
    ResponseTransformType.Input == InnerMiddlewareType.Output, ResponseTransformType.Output == Void,
    ResponseTransformType.Context == RouterType.InnerMiddlewareContext, RequestTransformType.Context == RouterType.InnerMiddlewareContext {
        let stack = MiddlewareTransformStack(requestTransform: requestTransform, responseTransform: responseTransform) {
            if let outerMiddleware = outerMiddleware {
                outerMiddleware
            }
            
            // Add middleware to all routes within the router but outside the transformation (operates on Request and Response types)
            JSONSmokeReturnableErrorMiddleware<ErrorType, RouterType.InnerMiddlewareContext>(allowedErrors: allowedErrors)
        } inner: {
            if let innerMiddleware = innerMiddleware {
                innerMiddleware
            }
            
            // Add middleware to all routes within the transformation (operates on operation Input and Output types)
        }
        
        self.router.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod,
                                           middlewareStack: stack, operation: operation,
                                           applicationContextProvider: self.applicationContextProvider)
    }
}
