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
import Logging

internal struct EmptyMiddleware<Input, OutputWriter, Context>: MiddlewareProtocol {
    public func handle(_ input: Input,
                       outputWriter: OutputWriter,
                       context: Context,
                       next: (Input, OutputWriter, Context) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
    }
}

public struct SmokeMiddlewareContext: ContextWithMutableLogger, ContextWithMutableRequestId {
    public var logger: Logging.Logger?
    public var internalRequestId: String?
    
    public init(logger: Logging.Logger? = nil,
                internalRequestId: String? = nil) {
        self.logger = logger
        self.internalRequestId = internalRequestId
    }
}

/**
 Protocol that manages adding handlers for operations using a defined middleware stack.
 */
public protocol ServerMiddlewareStackProtocol {
    associatedtype RouterType: ServerRouterProtocol
    associatedtype IncomingOutputWriter: HTTPServerResponseWriterProtocol
    associatedtype ApplicationContextType
    
    init(serverName: String,
         serverConfiguration: SmokeServerConfiguration<RouterType.OperationIdentifer>,
         applicationContextProvider:
         @escaping @Sendable (HTTPServerRequestContext<RouterType.OperationIdentifer>) -> ApplicationContextType)
    
    @Sendable func handle(request: HTTPServerRequest, responseWriter: IncomingOutputWriter) async
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     The output of the `operation` is used to populate the `InnerMiddlewareType.OutgoingOutputWriter` which must conform to `TypedOutputWriterProtocol`.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type
        - transformMiddleware: The middleware to transform the request and response into the operation's input and output types.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (InnerMiddlewareType.OutgoingInput, ApplicationContextType) async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    // requirements for OuterMiddlewareType -> TransformMiddleware
    TransformMiddlewareType.IncomingInput == OuterMiddlewareType.OutgoingInput,
    TransformMiddlewareType.IncomingOutputWriter == OuterMiddlewareType.OutgoingOutputWriter,
    TransformMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // requirements for TransformMiddleware -> InnerMiddlewareType
    InnerMiddlewareType.IncomingInput == TransformMiddlewareType.OutgoingInput,
    InnerMiddlewareType.IncomingOutputWriter == TransformMiddlewareType.OutgoingOutputWriter,
    InnerMiddlewareType.IncomingContext == TransformMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the outer middleware cannot change the input type
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     The `InnerMiddlewareType.OutgoingOutputWriter` instance is passed directly to the `operation` and there are no constraints of this type.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type
        - transformMiddleware: The middleware to transform the request and response into the operation's input and output types.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         TransformMiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (InnerMiddlewareType.OutgoingInput,
                                          InnerMiddlewareType.OutgoingOutputWriter, ApplicationContextType) async throws -> (),
          allowedErrors: [(ErrorType, Int)], outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType,
          transformMiddleware: TransformMiddlewareType)
    where
    // requirements for OuterMiddlewareType -> TransformMiddleware
    TransformMiddlewareType.IncomingInput == OuterMiddlewareType.OutgoingInput,
    TransformMiddlewareType.IncomingOutputWriter == OuterMiddlewareType.OutgoingOutputWriter,
    TransformMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // requirements for TransformMiddleware -> InnerMiddlewareType
    InnerMiddlewareType.IncomingInput == TransformMiddlewareType.OutgoingInput,
    InnerMiddlewareType.IncomingOutputWriter == TransformMiddlewareType.OutgoingOutputWriter,
    InnerMiddlewareType.IncomingContext == TransformMiddlewareType.OutgoingContext,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    // the outer middleware cannot change the input type
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    // requirements for the transform context
    TransformMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // requirements for operation handling
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext
}

public extension ServerMiddlewareStackProtocol {
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     A single middleware stack is provided, which is free to transform the input, output writer into what will be provided to the `operation`.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
     - operation: the operation handler to add.
        - middleware: The middleware stack that is called prior to calling the operation.
     */
    mutating func addHandlerForOperation<MiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (MiddlewareType.OutgoingInput,
                                        MiddlewareType.OutgoingOutputWriter, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], middleware: MiddlewareType)
    where
    MiddlewareType.IncomingOutputWriter: HTTPServerResponseWriterProtocol,
    MiddlewareType.IncomingContext == RouterType.RouterMiddlewareContext,
    MiddlewareType.IncomingInput == HTTPServerRequest,
    MiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    MiddlewareType.IncomingOutputWriter == RouterType.OutputWriter {
        let emptyMiddleware: EmptyMiddleware<MiddlewareType.IncomingInput, MiddlewareType.IncomingOutputWriter,
                                             MiddlewareType.IncomingContext> = .init()
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: emptyMiddleware, innerMiddleware: middleware,
                                    transformMiddleware: emptyMiddleware)
    }
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     A single middleware stack is provided, which is free to transform the input, output writer into what will be provided to the `operation`.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - operationProvider: provider of the operation handler to add.
        - middleware: The middleware stack that is called prior to calling the operation.
     */
    mutating func addHandlerForOperationProvider<MiddlewareType: TransformingMiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (MiddlewareType.OutgoingInput,
                                                                             MiddlewareType.OutgoingOutputWriter) async throws -> ()),
        allowedErrors: [(ErrorType, Int)], middleware: MiddlewareType)
    where
    MiddlewareType.IncomingOutputWriter: HTTPServerResponseWriterProtocol,
    MiddlewareType.IncomingContext == RouterType.RouterMiddlewareContext,
    MiddlewareType.IncomingInput == HTTPServerRequest,
    MiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    MiddlewareType.IncomingOutputWriter == RouterType.OutputWriter {
        let emptyMiddleware: EmptyMiddleware<MiddlewareType.IncomingInput, MiddlewareType.IncomingOutputWriter,
                                             MiddlewareType.IncomingContext> = .init()
        
        @Sendable func innerOperation(_ input: MiddlewareType.OutgoingInput,
                                      outputWriter: MiddlewareType.OutgoingOutputWriter,
                                      context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            try await operation(input, outputWriter)
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                    allowedErrors: allowedErrors, outerMiddleware: emptyMiddleware, innerMiddleware: middleware,
                                    transformMiddleware: emptyMiddleware)
    }
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     No middleware is provided so the `HTTPServerRequest` and `IncomingOutputWriter` are provided directly to the operation.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - operation: the operation handler to add.
        - middleware: The middleware stack that is called prior to calling the operation.
     */
    mutating func addHandlerForOperation<ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (HTTPServerRequest,
                                        IncomingOutputWriter, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)])
    where IncomingOutputWriter == RouterType.OutputWriter {
        let emptyMiddleware: EmptyMiddleware<HTTPServerRequest, IncomingOutputWriter,
                                             RouterType.RouterMiddlewareContext> = .init()
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: emptyMiddleware, innerMiddleware: emptyMiddleware,
                                    transformMiddleware: emptyMiddleware)
    }
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack.
     No middleware is provided so the `HTTPServerRequest` and `IncomingOutputWriter` are provided directly to the operation.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - operationProvider: provider of the operation handler to add.
        - middleware: The middleware stack that is called prior to calling the operation.
     */
    mutating func addHandlerForOperationProvider<ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (HTTPServerRequest,
                                                                             IncomingOutputWriter) async throws -> ()),
        allowedErrors: [(ErrorType, Int)])
    where IncomingOutputWriter == RouterType.OutputWriter {
        let emptyMiddleware: EmptyMiddleware<HTTPServerRequest, IncomingOutputWriter,
                                             RouterType.RouterMiddlewareContext> = .init()
        
        @Sendable func innerOperation(_ input: HTTPServerRequest,
                                      outputWriter: IncomingOutputWriter,
                                      context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            try await operation(input, outputWriter)
        }
        
        self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                    allowedErrors: allowedErrors, outerMiddleware: emptyMiddleware, innerMiddleware: emptyMiddleware,
                                    transformMiddleware: emptyMiddleware)
    }
}
