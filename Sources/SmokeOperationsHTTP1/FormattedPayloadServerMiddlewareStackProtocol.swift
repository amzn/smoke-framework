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
//  FormattedPayloadServerMiddlewareStackProtocol.swift
//  SmokeOperationsHTTP1
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations

public protocol FormattedPayloadServerMiddlewareStackProtocol {
    associatedtype RouterType: ServerRouterProtocol
    associatedtype ApplicationContextType
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack and the request and response transforms specified by this type.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response status to use for a success payload.
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type.
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.Output: OperationHTTP1OutputProtocol
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack and the request and response transforms specified by this type.
     This variant provides the ability to specify additional request and response transforms to handle transforming the request and response from the
     raw presentation used on the wire (serialized and deserialized by the standard transformed for this formatted payload) to an internal
     representation that the application wants to use.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response status to use for a success payload.
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type.
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type.
        - innerRequestTransform: The transformation operation to transform raw deserialized .
        - innerResponseTransform: The transformation operation to transform the operation's output type into the response.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
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
    InnerRequestTransformType.Input: OperationHTTP1InputProtocol, InnerResponseTransformType.Output: OperationHTTP1OutputProtocol
}
