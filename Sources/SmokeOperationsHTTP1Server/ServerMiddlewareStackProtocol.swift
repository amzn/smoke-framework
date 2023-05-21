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
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeOperations
import SmokeAsyncHTTP1Server
import SmokeOperationsHTTP1
import SmokeHTTP1ServerMiddleware
import Logging

public struct SmokeMiddlewareContext: ContextWithMutableLogger, ContextWithMutableRequestId, ContextWithResponseWriter {
    public let responseWriter: HTTPServerResponseWriterProtocol
    public var logger: Logging.Logger?
    public var internalRequestId: String?
    
    public init(responseWriter: HTTPServerResponseWriterProtocol,
                logger: Logging.Logger? = nil,
                internalRequestId: String? = nil) {
        self.responseWriter = responseWriter
        self.logger = logger
        self.internalRequestId = internalRequestId
    }
}

/**
 Protocol that manages adding handlers for operations using a defined middleware stack.
 */
public protocol ServerMiddlewareStackProtocol {
    associatedtype RouterType: ServerRouterProtocol where RouterType.OuterMiddlewareContext == SmokeMiddlewareContext
    associatedtype ApplicationContextType
    
    init(serverName: String,
         serverConfiguration: SmokeServerConfiguration<RouterType.OperationIdentifer>,
         applicationContextProvider:
         @escaping @Sendable (HTTPServerRequestContext<RouterType.OperationIdentifer>) -> ApplicationContextType)
    
    @Sendable func handle(request: HTTPServerRequest, responseWriter: HTTPServerResponseWriter) async
    
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
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    RequestTransformType.Input == HTTPServerRequest, RequestTransformType.Output == InnerMiddlewareType.Input,
    ResponseTransformType.Input == InnerMiddlewareType.Output, ResponseTransformType.Output == Void,
    ResponseTransformType.Context == RouterType.InnerMiddlewareContext, RequestTransformType.Context == RouterType.InnerMiddlewareContext
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     The operation has no input or output.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response code to send on a successful operation.
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output == Void
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     The operation has no input or output.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response code to send on a successful operation.
        - operationProvider: when given a `ContextType` instance will provide the handler method for the operation.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type
     */
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output == Void
}

public extension ServerMiddlewareStackProtocol {
    /**
     Default implementation
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output == Void {
        let requestTransform: VoidRequestTransform<RouterType.InnerMiddlewareContext> = .init()
        let responseTransform: VoidResponseTransform<RouterType.InnerMiddlewareContext> =
            .init(statusOnSuccess: statusOnSuccess)
        
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            return try await operation(context)
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                    operation: innerOperation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     Default implementation
     */
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output == Void {
        let requestTransform: VoidRequestTransform<RouterType.InnerMiddlewareContext> = .init()
        let responseTransform: VoidResponseTransform<RouterType.InnerMiddlewareContext> =
            .init(statusOnSuccess: statusOnSuccess)
        
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                    operation: innerOperation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
}

public extension ServerMiddlewareStackProtocol {
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output == Void {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.InnerMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext {
        let innerMiddleware: EmptyMiddleware<Void, Void, RouterType.InnerMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus)
    {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.InnerMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Void, Void, RouterType.InnerMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> ()),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output == Void {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.InnerMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> ()),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == Void,
    OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let innerMiddleware: EmptyMiddleware<Void, Void, RouterType.InnerMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> ()),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus)
    {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.InnerMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Void, Void, RouterType.InnerMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
}
