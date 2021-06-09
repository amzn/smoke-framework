// Copyright 2018-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeHTTP1HandlerSelector+fromProviderWithInputNoOutput.swift
// _SmokeOperationsHTTP1Concurrency
//

#if compiler(>=5.5) && $AsyncAwait

import Foundation
import SmokeOperations
import _SmokeOperationsConcurrency
import NIOHTTP1
import Logging
import SmokeOperationsHTTP1

public extension SmokeHTTP1HandlerSelector {
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operationProvider: when given a `ContextType` instance will provide the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - inputLocation: the location in the incoming http request to decode the input from.
     */
    @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
    mutating func addHandlerForOperationProvider<InputType: ValidatableCodable, ErrorType: ErrorIdentifiableByDescription>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> Void)),
            allowedErrors: [(ErrorType, Int)],
            inputLocation: OperationInputHTTPLocation) {
        func operation(input: InputType, context: ContextType) async throws {
            let innerOperation = operationProvider(context)
            try await innerOperation(input)
        }
        
        addHandlerForOperation(operationIdentifer,
                               httpMethod: httpMethod,
                               operation: operation,
                               allowedErrors: allowedErrors,
                               inputLocation: inputLocation)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operationProvider: when given a `ContextType` instance will provide the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - inputLocation: the location in the incoming http request to decode the input from.
        - operationDelegate: an operation-specific delegate to use when
          handling the operation.
     */
    @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
    mutating func addHandlerForOperationProvider<InputType: ValidatableCodable, ErrorType: ErrorIdentifiableByDescription,
        OperationDelegateType: HTTP1OperationDelegate>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> Void)),
            allowedErrors: [(ErrorType, Int)],
            inputLocation: OperationInputHTTPLocation,
            operationDelegate: OperationDelegateType)
    where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
    DefaultOperationDelegateType.InvocationReportingType == OperationDelegateType.InvocationReportingType,
    DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        func operation(input: InputType, context: ContextType) async throws {
            let innerOperation = operationProvider(context)
            try await innerOperation(input)
        }
        
        addHandlerForOperation(operationIdentifer,
                               httpMethod: httpMethod,
                               operation: operation,
                               allowedErrors: allowedErrors,
                               inputLocation: inputLocation,
                               operationDelegate: operationDelegate)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operationProvider: when given a `ContextType` instance will provide the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
     */
    @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
    mutating func addHandlerForOperationProvider<InputType: ValidatableOperationHTTP1InputProtocol, ErrorType: ErrorIdentifiableByDescription>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> Void)),
            allowedErrors: [(ErrorType, Int)]) {
        func operation(input: InputType, context: ContextType) async throws {
            let innerOperation = operationProvider(context)
            try await innerOperation(input)
        }
        
        addHandlerForOperation(operationIdentifer,
                               httpMethod: httpMethod,
                               operation: operation,
                               allowedErrors: allowedErrors)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operationProvider: when given a `ContextType` instance will provide the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: an operation-specific delegate to use when
          handling the operation.
     */
    @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
    mutating func addHandlerForOperationProvider<InputType: ValidatableOperationHTTP1InputProtocol,
            ErrorType: ErrorIdentifiableByDescription,
            OperationDelegateType: HTTP1OperationDelegate>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> Void)),
            allowedErrors: [(ErrorType, Int)],
            operationDelegate: OperationDelegateType)
    where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
    DefaultOperationDelegateType.InvocationReportingType == OperationDelegateType.InvocationReportingType,
    DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        func operation(input: InputType, context: ContextType) async throws {
            let innerOperation = operationProvider(context)
            try await innerOperation(input)
        }
        
        addHandlerForOperation(operationIdentifer,
                               httpMethod: httpMethod,
                               operation: operation,
                               allowedErrors: allowedErrors,
                               operationDelegate: operationDelegate)
    }
}

#endif
