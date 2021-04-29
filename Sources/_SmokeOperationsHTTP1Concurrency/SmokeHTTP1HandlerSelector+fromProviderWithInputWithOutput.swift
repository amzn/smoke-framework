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
// SmokeHTTP1HandlerSelector+fromProviderWithInputWithOutput.swift
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
        - outputLocation: the location in the outgoing http response to place the encoded output.
     */
    mutating func addHandlerForOperationProvider<InputType: ValidatableCodable, OutputType: ValidatableCodable,
            ErrorType: ErrorIdentifiableByDescription>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> OutputType)),
            allowedErrors: [(ErrorType, Int)],
            inputLocation: OperationInputHTTPLocation,
            outputLocation: OperationOutputHTTPLocation) {
        func operation(input: InputType, context: ContextType) async throws -> OutputType {
            let innerOperation = operationProvider(context)
            return try await innerOperation(input)
        }
        
        addHandlerForOperation(operationIdentifer,
                               httpMethod: httpMethod,
                               operation: operation,
                               allowedErrors: allowedErrors,
                               inputLocation: inputLocation,
                               outputLocation: outputLocation)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operationProvider: when given a `ContextType` instance will provide the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - inputLocation: the location in the incoming http request to decode the input from.
        - outputLocation: the location in the outgoing http response to place the encoded output.
        - operationDelegate: an operation-specific delegate to use when
          handling the operation.
     */
    mutating func addHandlerForOperationProvider<InputType: ValidatableCodable, OutputType: ValidatableCodable,
            ErrorType: ErrorIdentifiableByDescription, OperationDelegateType: HTTP1OperationDelegate>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> OutputType)),
            allowedErrors: [(ErrorType, Int)],
            inputLocation: OperationInputHTTPLocation,
            outputLocation: OperationOutputHTTPLocation,
            operationDelegate: OperationDelegateType)
    where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
    DefaultOperationDelegateType.InvocationReportingType == OperationDelegateType.InvocationReportingType,
    DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        func operation(input: InputType, context: ContextType) async throws -> OutputType {
            let innerOperation = operationProvider(context)
            return try await innerOperation(input)
        }
            
        addHandlerForOperation(operationIdentifer,
                               httpMethod: httpMethod,
                               operation: operation,
                               allowedErrors: allowedErrors,
                               inputLocation: inputLocation,
                               outputLocation: outputLocation,
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
    mutating func addHandlerForOperationProvider<InputType: ValidatableOperationHTTP1InputProtocol,
            OutputType: ValidatableOperationHTTP1OutputProtocol,
            ErrorType: ErrorIdentifiableByDescription>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> OutputType)),
            allowedErrors: [(ErrorType, Int)]) {
        func operation(input: InputType, context: ContextType) async throws -> OutputType {
            let innerOperation = operationProvider(context)
            return try await innerOperation(input)
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
    mutating func addHandlerForOperationProvider<InputType: ValidatableOperationHTTP1InputProtocol,
            OutputType: ValidatableOperationHTTP1OutputProtocol,
            ErrorType: ErrorIdentifiableByDescription, OperationDelegateType: HTTP1OperationDelegate>(
            _ operationIdentifer: OperationIdentifer,
            httpMethod: HTTPMethod,
            operationProvider: @escaping ((ContextType) -> ((InputType) async throws -> OutputType)),
            allowedErrors: [(ErrorType, Int)],
            operationDelegate: OperationDelegateType)
    where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
    DefaultOperationDelegateType.InvocationReportingType == OperationDelegateType.InvocationReportingType,
    DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        func operation(input: InputType, context: ContextType) async throws -> OutputType {
            let innerOperation = operationProvider(context)
            return try await innerOperation(input)
        }
        
        addHandlerForOperation(operationIdentifer,
                               httpMethod: httpMethod,
                               operation: operation,
                               allowedErrors: allowedErrors)
    }
}

#endif
