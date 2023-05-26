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
//  JSONPayloadServerMiddlewareHelper.swift
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations
import SmokeOperationsHTTP1

public struct JSONPayloadServerMiddlewareHelper<MiddlewareStackType: ServerMiddlewareStackProtocol>:
FormattedPayloadServerMiddlewareHelperProtocol {
    public typealias RouterType = MiddlewareStackType.RouterType
    public typealias ApplicationContextType = MiddlewareStackType.ApplicationContextType
        
    public init() {

    }
    
    /**
     Input. Output.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, InnerMiddlewareType.OutputWriter, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        let transformerMiddleware = JSONRequestTransformMiddleware<OuterMiddlewareType.OutputWriter,
                                                                   InnerMiddlewareType.Input,
                                                                   InnerMiddlewareType.OutputWriter,
                                                                   RouterType.RouterMiddlewareContext> { wrappedWriter in
            JSONTypedOutputWriter<InnerMiddlewareType.OutputWriter.OutputType, OuterMiddlewareType.OutputWriter>(
                status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
        
        middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                               operation: operation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                               requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     Input. No Output.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType == Void {
        let requestTransform: JSONRequestTransform<InnerMiddlewareType.Input, RouterType.IncomingMiddlewareContext> =
            getStandardRequestTransform()
        let responseTransform: VoidResponseTransform<RouterType.IncomingMiddlewareContext> =
            .init(statusOnSuccess: statusOnSuccess)
        
        middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                               operation: operation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                               requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     No Input. Output.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
        InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        let requestTransform: VoidRequestTransform<RouterType.IncomingMiddlewareContext> = .init()
        let responseTransform: JSONResponseTransform<InnerMiddlewareType.Output, RouterType.IncomingMiddlewareContext> =
            getStandardResponseTransform(statusOnSuccess: statusOnSuccess)
        
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            return try await operation(context)
        }
        
        middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                               operation: innerOperation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                               requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    private func getStandardRequestTransform<OutputType: OperationHTTP1InputProtocol>()
    -> JSONRequestTransform<OutputType, RouterType.IncomingMiddlewareContext> {
        return JSONRequestTransform()
    }
    
    private func getStandardResponseTransform<InputType: OperationHTTP1OutputProtocol>(statusOnSuccess: HTTPResponseStatus)
    -> JSONResponseTransform<InputType, RouterType.IncomingMiddlewareContext> {
        return JSONResponseTransform(status: statusOnSuccess)
    }
}
