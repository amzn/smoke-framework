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
//  SmokeOperationsHTTP1
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations

public struct JSONPayloadServerMiddlewareStack<MiddlewareStackType: ServerMiddlewareStackProtocol>:
FormattedPayloadServerMiddlewareStackProtocol {
    public typealias RouterType = MiddlewareStackType.RouterType
    public typealias ApplicationContextType = MiddlewareStackType.ApplicationContextType
    
    private var middlewareStack: MiddlewareStackType
    
    public init(middlewareStack: MiddlewareStackType) {
        self.middlewareStack = middlewareStack
    }
    
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
    
    private func getStandardRequestTransform<OutputType: OperationHTTP1InputProtocol>()
    -> JSONRequestTransform<OutputType, RouterType.InnerMiddlewareContext> {
        return JSONRequestTransform()
    }
    
    private func getStandardResponseTransform<InputType: OperationHTTP1OutputProtocol>(statusOnSuccess: HTTPResponseStatus)
    -> JSONResponseTransform<InputType, RouterType.InnerMiddlewareContext> {
        return JSONResponseTransform(status: statusOnSuccess)
    }
}
