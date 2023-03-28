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
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations
import SmokeOperationsHTTP1

public protocol FormattedPayloadServerMiddlewareStackProtocol {
    associatedtype RouterType: ServerRouterProtocol
    associatedtype ApplicationContextType
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack and the request and response transforms specified by this type.
     Operation handler provides an input and an output.
 
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
     Operation handler provides an input and no output.
 
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
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> (),
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.Output == Void
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack and the request and response transforms specified by this type.
     Operation handler provides no input and an output.
 
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
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output: OperationHTTP1OutputProtocol
}

public extension FormattedPayloadServerMiddlewareStackProtocol {

    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (InnerMiddlewareType.Input) async throws -> InnerMiddlewareType.Output),
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.Output: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            let operation = operationProvider(context)
            return try await operation(input)
        }
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                           statusOnSuccess: statusOnSuccess, operation: innerOperation, outerMiddleware: outerMiddleware,
                                           innerMiddleware: innerMiddleware)
    }
    
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (InnerMiddlewareType.Input) async throws -> Void),
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.Output == Void {
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            try await operation(input)
        }
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                           statusOnSuccess: statusOnSuccess, operation: innerOperation, outerMiddleware: outerMiddleware,
                                           innerMiddleware: innerMiddleware)
    }
    
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.Output),
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.Output == HTTPServerResponse,
    InnerMiddlewareType.Context == RouterType.InnerMiddlewareContext, OuterMiddlewareType.Context == RouterType.InnerMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.Output: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, allowedErrors: allowedErrors,
                                           statusOnSuccess: statusOnSuccess, operation: innerOperation, outerMiddleware: outerMiddleware,
                                           innerMiddleware: innerMiddleware)
    }
}

