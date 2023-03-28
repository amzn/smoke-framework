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
//  JSONPayloadServerMiddlewareStack.swift
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations
import SmokeOperationsHTTP1

public struct JSONPayloadServerMiddlewareStack<MiddlewareStackType: ServerMiddlewareStackProtocol>:
FormattedPayloadServerMiddlewareStackProtocol {
    public typealias RouterType = MiddlewareStackType.RouterType
    public typealias ApplicationContextType = MiddlewareStackType.ApplicationContextType
    
    private var middlewareStack: MiddlewareStackType
    
    public init(middlewareStack: MiddlewareStackType) {
        self.middlewareStack = middlewareStack
    }
    
    /**
     Input. Output. Standard transforms only.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.Output: OperationHTTP1OutputProtocol {
        let requestTransform: JSONRequestTransform<InnerMiddlewareType.Input, RouterType.InnerMiddlewareContext> =
            getStandardRequestTransform()
        let responseTransform: JSONResponseTransform<InnerMiddlewareType.Output, RouterType.InnerMiddlewareContext> =
            getStandardResponseTransform(statusOnSuccess: statusOnSuccess)
        
        self.middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                                    operation: operation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     Input. No Output. Standard transforms only.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> (),
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.Output == Void {
        let requestTransform: JSONRequestTransform<InnerMiddlewareType.Input, RouterType.InnerMiddlewareContext> =
            getStandardRequestTransform()
        let responseTransform: VoidResponseTransform<RouterType.InnerMiddlewareContext> =
            .init(statusOnSuccess: statusOnSuccess)
        
        self.middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                                    operation: operation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     No Input. Output. Standard transforms only.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output: OperationHTTP1OutputProtocol {
        let requestTransform: VoidRequestTransform<RouterType.InnerMiddlewareContext> = .init()
        let responseTransform: JSONResponseTransform<InnerMiddlewareType.Output, RouterType.InnerMiddlewareContext> =
            getStandardResponseTransform(statusOnSuccess: statusOnSuccess)
        
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            return try await operation(context)
        }
        
        self.middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                                    operation: innerOperation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     Input. Output. Standard + additional transforms.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                InnerRequestTransformType: TransformProtocol, InnerResponseTransformType: TransformProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        innerRequestTransform: InnerRequestTransformType, innerResponseTransform: InnerResponseTransformType)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerRequestTransformType.Output == InnerMiddlewareType.Input, InnerResponseTransformType.Input == InnerMiddlewareType.Output,
    InnerResponseTransformType.Context == RouterType.InnerMiddlewareContext, InnerRequestTransformType.Context == RouterType.InnerMiddlewareContext,
    InnerRequestTransformType.Input: OperationHTTP1InputProtocol, InnerResponseTransformType.Output: OperationHTTP1OutputProtocol {
        let standardRequestTransform: JSONRequestTransform<InnerRequestTransformType.Input, RouterType.InnerMiddlewareContext> =
            getStandardRequestTransform()
        let standardResponseTransform: JSONResponseTransform<InnerResponseTransformType.Output, RouterType.InnerMiddlewareContext> =
            getStandardResponseTransform(statusOnSuccess: statusOnSuccess)
        
        let requestTransform = TransformTuple(standardRequestTransform, innerRequestTransform)
        let responseTransform = TransformTuple(innerResponseTransform, standardResponseTransform)
        
        self.middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                                    operation: operation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     Input. No Output. Standard + additional transforms.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                InnerRequestTransformType: TransformProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> (),
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        innerRequestTransform: InnerRequestTransformType)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerRequestTransformType.Output == InnerMiddlewareType.Input, InnerRequestTransformType.Context == RouterType.InnerMiddlewareContext,
    InnerRequestTransformType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.Output == Void {
        let standardRequestTransform: JSONRequestTransform<InnerRequestTransformType.Input, RouterType.InnerMiddlewareContext> =
            getStandardRequestTransform()
        let responseTransform: VoidResponseTransform<RouterType.InnerMiddlewareContext> =
            .init(statusOnSuccess: statusOnSuccess)
        
        let requestTransform = TransformTuple(standardRequestTransform, innerRequestTransform)
        
        self.middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                                    operation: operation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    /**
     No Input. Output. Standard + additional transforms.
     */
    public mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                InnerResponseTransformType: TransformProtocol,
                                                ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        innerResponseTransform: InnerResponseTransformType)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerResponseTransformType.Input == InnerMiddlewareType.Output, InnerResponseTransformType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerResponseTransformType.Output: OperationHTTP1OutputProtocol {
        let requestTransform: VoidRequestTransform<RouterType.InnerMiddlewareContext> = .init()
        let standardResponseTransform: JSONResponseTransform<InnerResponseTransformType.Output, RouterType.InnerMiddlewareContext> =
            getStandardResponseTransform(statusOnSuccess: statusOnSuccess)
        
        let responseTransform = TransformTuple(innerResponseTransform, standardResponseTransform)
        
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            return try await operation(context)
        }
        
        self.middlewareStack.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                                    operation: innerOperation, outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                                    requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    private func getStandardRequestTransform<OutputType: OperationHTTP1InputProtocol>()
    -> JSONRequestTransform<OutputType, RouterType.InnerMiddlewareContext> {
        return JSONRequestTransform()
    }
    
    private func getStandardResponseTransform<InputType: OperationHTTP1OutputProtocol>(statusOnSuccess: HTTPResponseStatus)
    -> JSONResponseTransform<InputType, RouterType.InnerMiddlewareContext> {
        return JSONResponseTransform(status: statusOnSuccess)
    }
}