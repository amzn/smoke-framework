// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeHTTP1HandlerSelector+blockingWithInputWithOutput.swift
// SmokeOperationsHTTP1
//

import Foundation
import LoggerAPI
import SmokeOperations
import NIOHTTP1

public extension SmokeHTTP1HandlerSelector {
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
     */
    mutating func addHandlerForUri<InputType: ValidatableCodable, OutputType: ValidatableCodable,
        ErrorType: ErrorIdentifiableByDescription>(
        _ uri: String,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType) throws -> OutputType),
        allowedErrors: [(ErrorType, Int)],
        inputLocation: OperationInputHTTPLocation,
        outputLocation: OperationOutputHTTPLocation) {
        
        // don't capture self
        let delegateToUse = defaultOperationDelegate
        func inputProvider(requestHead: DefaultOperationDelegateType.RequestHeadType, body: Data?) throws -> InputType {
            return try delegateToUse.getInputForOperation(
                requestHead: requestHead,
                body: body,
                location: inputLocation)
        }
        
        func outputHandler(requestHead: DefaultOperationDelegateType.RequestHeadType,
                           output: OutputType,
                           responseHandler: DefaultOperationDelegateType.ResponseHandlerType) {
            delegateToUse.handleResponseForOperation(requestHead: requestHead,
                                                     location: outputLocation,
                                                     output: output,
                                                     responseHandler: responseHandler)
        }
        
        let handler = OperationHandler(
            inputProvider: inputProvider,
            operation: operation,
            outputHandler: outputHandler,
            allowedErrors: allowedErrors,
            operationDelegate: defaultOperationDelegate)
        
        addHandlerForUri(uri, httpMethod: httpMethod, handler: handler)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: an operation-specific delegate to use when
          handling the operation.
     */
    mutating func addHandlerForUri<InputType: ValidatableCodable, OutputType: ValidatableCodable,
        ErrorType: ErrorIdentifiableByDescription, OperationDelegateType: HTTP1OperationDelegate>(
        _ uri: String,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType) throws -> OutputType),
        allowedErrors: [(ErrorType, Int)],
        inputLocation: OperationInputHTTPLocation,
        outputLocation: OperationOutputHTTPLocation,
        operationDelegate: OperationDelegateType)
        where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
        DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            
            func inputProvider(requestHead: OperationDelegateType.RequestHeadType, body: Data?) throws -> InputType {
                return try operationDelegate.getInputForOperation(
                    requestHead: requestHead,
                    body: body,
                    location: inputLocation)
            }
            
            func outputHandler(requestHead: OperationDelegateType.RequestHeadType,
                               output: OutputType,
                               responseHandler: OperationDelegateType.ResponseHandlerType) {
                operationDelegate.handleResponseForOperation(requestHead: requestHead,
                                                             location: outputLocation,
                                                             output: output,
                                                             responseHandler: responseHandler)
            }
            
            let handler = OperationHandler(
                inputProvider: inputProvider,
                operation: operation,
                outputHandler: outputHandler,
                allowedErrors: allowedErrors,
                operationDelegate: operationDelegate)
            
            addHandlerForUri(uri, httpMethod: httpMethod, handler: handler)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
     */
    mutating func addHandlerForUri<InputType: ValidatableOperationHTTP1InputProtocol,
        OutputType: ValidatableOperationHTTP1OutputProtocol,
        ErrorType: ErrorIdentifiableByDescription>(
        _ uri: String,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType) throws -> OutputType),
        allowedErrors: [(ErrorType, Int)]) {
        
        let handler = OperationHandler(
            inputProvider: defaultOperationDelegate.getInputForOperation,
            operation: operation,
            outputHandler: defaultOperationDelegate.handleResponseForOperation,
            allowedErrors: allowedErrors,
            operationDelegate: defaultOperationDelegate)
        
        addHandlerForUri(uri, httpMethod: httpMethod, handler: handler)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: an operation-specific delegate to use when
          handling the operation.
     */
    mutating func addHandlerForUri<InputType: ValidatableOperationHTTP1InputProtocol,
        OutputType: ValidatableOperationHTTP1OutputProtocol,
        ErrorType: ErrorIdentifiableByDescription, OperationDelegateType: HTTP1OperationDelegate>(
        _ uri: String,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType) throws -> OutputType),
        allowedErrors: [(ErrorType, Int)],
        operationDelegate: OperationDelegateType)
    where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
    DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        
        let handler = OperationHandler(
            inputProvider: operationDelegate.getInputForOperation,
            operation: operation,
            outputHandler: operationDelegate.handleResponseForOperation,
            allowedErrors: allowedErrors,
            operationDelegate: operationDelegate)
        
        addHandlerForUri(uri, httpMethod: httpMethod, handler: handler)
    }
}
