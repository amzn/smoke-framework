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
//  JSONPayloadServerMiddlewareHelper+operationWithInnerWithOuterMiddleware.swift
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations
import SmokeOperationsHTTP1
import SmokeHTTP1ServerMiddleware

public extension JSONPayloadServerMiddlewareHelper {
    
    /**
     Input. Output.
     */
    mutating func addHandlerForOperation<ResponseTransformOutputType: OperationHTTP1OutputProtocol,
                                         InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (InnerMiddlewareType.OutgoingInput, ApplicationContextType) async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
          outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.IncomingOutputWriter == JSONTypedOutputWriter<ResponseTransformOutputType, OuterMiddlewareType.OutgoingOutputWriter>,
    // the inner middleware must produce a `TypedOutputWriterProtocol` output writer
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the inner middleware incoming input and output types must be serializable
    InnerMiddlewareType.IncomingOutputWriter.OutputType: OperationHTTP1OutputProtocol,
    InnerMiddlewareType.IncomingInput: OperationHTTP1InputProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead & ContextWithPathShape,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext {
        let transformMiddleware = JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                                                 InnerMiddlewareType.IncomingInput,
                                                                 InnerMiddlewareType.IncomingOutputWriter,
                                                                 InnerMiddlewareType.IncomingContext> { wrappedWriter in
            JSONTypedOutputWriter<ResponseTransformOutputType,
                                  OuterMiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
        
        middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
    
    /**
     Input. No Output.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (InnerMiddlewareType.OutgoingInput, ApplicationContextType) async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
          outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.IncomingOutputWriter == VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>,
    // the inner middleware must produce a `TypedOutputWriterProtocol` output writer
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the inner middleware incoming input and output types must be serializable
    InnerMiddlewareType.IncomingInput: OperationHTTP1InputProtocol,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead & ContextWithPathShape,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext {
        let transformMiddleware = JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                                                 InnerMiddlewareType.IncomingInput,
                                                                 InnerMiddlewareType.IncomingOutputWriter,
                                                                 InnerMiddlewareType.IncomingContext> { wrappedWriter in
            VoidResponseWriter<OuterMiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
        
        middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
    
    /**
     No Input. Output.
     */
    mutating func addHandlerForOperation<ResponseTransformOutputType: OperationHTTP1OutputProtocol,
                                         InnerMiddlewareType: TransformingMiddlewareProtocol, OuterMiddlewareType: TransformingMiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
          _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
          operation: @escaping @Sendable (InnerMiddlewareType.OutgoingInput, ApplicationContextType) async throws
          -> InnerMiddlewareType.OutgoingOutputWriter.OutputType,
          allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
          outerMiddleware: OuterMiddlewareType, innerMiddleware: InnerMiddlewareType)
    where
    // the outer middleware cannot change the input type
    OuterMiddlewareType.IncomingInput == HTTPServerRequest,
    OuterMiddlewareType.OutgoingInput == HTTPServerRequest,
    // the output writer is always transformed from a HTTPServerResponseWriterProtocol to a TypedOutputWriterProtocol by the transform
    OuterMiddlewareType.OutgoingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.IncomingOutputWriter == JSONTypedOutputWriter<ResponseTransformOutputType, OuterMiddlewareType.OutgoingOutputWriter>,
    // the inner middleware must produce a `TypedOutputWriterProtocol` output writer
    InnerMiddlewareType.OutgoingOutputWriter: TypedOutputWriterProtocol,
    // the inner middleware incoming input and output types must be serializable
    InnerMiddlewareType.IncomingOutputWriter.OutputType: OperationHTTP1OutputProtocol,
    InnerMiddlewareType.IncomingInput == Void,
    // requirements for any added middleware
    OuterMiddlewareType.OutgoingContext: ContextWithMutableLogger,
    // the outer middleware output writer and context must be the same as the router itself
    RouterType.OutputWriter == OuterMiddlewareType.IncomingOutputWriter,
    RouterType.RouterMiddlewareContext == OuterMiddlewareType.IncomingContext,
    // requirements for the context coming out of the middleware
    InnerMiddlewareType.IncomingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead & ContextWithPathShape,
    InnerMiddlewareType.OutgoingContext: ContextWithMutableLogger & ContextWithMutableRequestId & ContextWithHTTPServerRequestHead,
    // the transform doesn't change the context type
    InnerMiddlewareType.IncomingContext == OuterMiddlewareType.OutgoingContext {
        let transformMiddleware = VoidRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                                                 InnerMiddlewareType.IncomingOutputWriter,
                                                                 InnerMiddlewareType.IncomingContext> { wrappedWriter in
            JSONTypedOutputWriter<ResponseTransformOutputType,
                                  OuterMiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
        
        middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                    allowedErrors: allowedErrors, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                    transformMiddleware: transformMiddleware)
    }
}
