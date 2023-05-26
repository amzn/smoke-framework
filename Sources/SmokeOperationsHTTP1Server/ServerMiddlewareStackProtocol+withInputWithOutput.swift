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
//  ServerMiddlewareStackProtocol+withInputWithOutput.swift
//  SmokeOperationsHTTP1Server
//
/*
import SwiftMiddleware
import NIOHTTP1
import SmokeOperations
import SmokeAsyncHTTP1Server
import SmokeOperationsHTTP1
import SmokeHTTP1ServerMiddleware
import Logging

public extension ServerMiddlewareStackProtocol {
    // Inner and Outer Middleware
    mutating func addHandlerForOperation<InputType: OperationHTTP1InputProtocol,
                                         OutputType: OperationHTTP1OutputProtocol,
                                         InnerMiddlewareType: TransformingMiddlewareProtocol,
                                         OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (InputType, ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.OutgoingOutputWriter.OutputType),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the inner middleware cannot change the input type or the output type of the writer
    InnerMiddlewareType.IncomingInput == InputType, InnerMiddlewareType.IncomingOutputWriter.OutputType == OutputType,
    InnerMiddlewareType.OutgoingInput == InputType, InnerMiddlewareType.OutgoingOutputWriter.OutputType == OutputType,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext,
    // the transform will wrap the writer in a `VoidResponseWriter`
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter> {
        @Sendable func innerOperation(_ input: InputType, context: ApplicationContextType) async throws -> OutputType {
            let operation = operationProvider(input, context)
            return try await operation()
        }
                
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    /*
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          innerMiddleware: InnerMiddlewareType)
    where
    // the inner middleware cannot change the input type or the output type of the writer
    InnerMiddlewareType.IncomingInput == Void, InnerMiddlewareType.IncomingOutputWriter.OutputType == Void,
    InnerMiddlewareType.OutgoingInput == Void, InnerMiddlewareType.OutgoingOutputWriter.OutputType == Void,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == RouterType.RouterMiddlewareContext,
    // the transform will wrap the writer in a `VoidResponseWriter`
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<RouterType.OutputWriter> {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> (),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          outerMiddleware: OuterMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead {
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>, OuterMiddlewareType.OutgoingContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod,
                                           operation: operation, allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (ApplicationContextType) async throws -> (),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus) {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<RouterType.OutputWriter>, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.OutgoingOutputWriter.OutputType),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          innerMiddleware: InnerMiddlewareType)
    where
    // the inner middleware cannot change the input type or the output type of the writer
    InnerMiddlewareType.IncomingInput == Void, InnerMiddlewareType.IncomingOutputWriter.OutputType == Void,
    InnerMiddlewareType.OutgoingInput == Void, InnerMiddlewareType.OutgoingOutputWriter.OutputType == Void,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == RouterType.RouterMiddlewareContext,
    // the transform will wrap the writer in a `VoidResponseWriter`
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<RouterType.OutputWriter> {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> ()),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
          outerMiddleware: OuterMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>, OuterMiddlewareType.OutgoingContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod,
                                           operation: innerOperation, allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> ()),
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus) {
        @Sendable func innerOperation(context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            return try await operation()
        }
              
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, RouterType.OutputWriter, RouterType.RouterMiddlewareContext> = .init()
        let innerMiddleware: EmptyMiddleware<Void, VoidResponseWriter<RouterType.OutputWriter>, RouterType.RouterMiddlewareContext> = .init()
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }*/
}*/
