// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  SmokeHTTP1HandlerSelector+nonblockingWithContextInputWithOutput.swift
//  SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations
import NIOHTTP1
import Logging

public extension SmokeHTTP1HandlerSelector {
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
     */
    mutating func addHandlerForOperation<InputType: ValidatableCodable, OutputType: ValidatableCodable,
            ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeServerInvocationReporting<TraceContextType>,
                       @escaping (Result<OutputType, Swift.Error>) -> ()) throws -> ()),
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
                           responseHandler: DefaultOperationDelegateType.ResponseHandlerType,
                           invocationContext: SmokeServerInvocationContext<TraceContextType>) {
            delegateToUse.handleResponseForOperation(requestHead: requestHead,
                                                     location: outputLocation,
                                                     output: output,
                                                     responseHandler: responseHandler,
                                                     invocationContext: invocationContext)
        }
        
        let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
            inputProvider: inputProvider,
            operation: operation,
            outputHandler: outputHandler,
            allowedErrors: allowedErrors,
            operationDelegate: defaultOperationDelegate)
        
        addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
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
    mutating func addHandlerForOperation<InputType: ValidatableCodable, OutputType: ValidatableCodable,
            ErrorType: ErrorIdentifiableByDescription, OperationDelegateType: HTTP1OperationDelegate>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeServerInvocationReporting<TraceContextType>,
                       @escaping (Result<OutputType, Swift.Error>) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)],
        inputLocation: OperationInputHTTPLocation,
        outputLocation: OperationOutputHTTPLocation,
        operationDelegate: OperationDelegateType)
        where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
        DefaultOperationDelegateType.TraceContextType == OperationDelegateType.TraceContextType,
        DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            
            func inputProvider(requestHead: OperationDelegateType.RequestHeadType, body: Data?) throws -> InputType {
                return try operationDelegate.getInputForOperation(
                    requestHead: requestHead,
                    body: body,
                    location: inputLocation)
            }
            
            func outputHandler(requestHead: OperationDelegateType.RequestHeadType,
                               output: OutputType,
                               responseHandler: OperationDelegateType.ResponseHandlerType,
                               invocationContext: SmokeServerInvocationContext<TraceContextType>) {
                operationDelegate.handleResponseForOperation(requestHead: requestHead,
                                                             location: outputLocation,
                                                             output: output,
                                                             responseHandler: responseHandler,
                                                             invocationContext: invocationContext)
            }
            
            let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
                inputProvider: inputProvider,
                operation: operation,
                outputHandler: outputHandler,
                allowedErrors: allowedErrors,
                operationDelegate: operationDelegate)
            
            addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
     */
    mutating func addHandlerForOperation<InputType: ValidatableOperationHTTP1InputProtocol, OutputType: ValidatableOperationHTTP1OutputProtocol,
            ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeServerInvocationReporting<TraceContextType>,
                       @escaping (Result<OutputType, Swift.Error>) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)]) {
        
        let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
            inputProvider: defaultOperationDelegate.getInputForOperation,
            operation: operation,
            outputHandler: defaultOperationDelegate.handleResponseForOperation,
            allowedErrors: allowedErrors,
            operationDelegate: defaultOperationDelegate)
        
        addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
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
    mutating func addHandlerForOperation<InputType: ValidatableOperationHTTP1InputProtocol, OutputType: ValidatableOperationHTTP1OutputProtocol,
            ErrorType: ErrorIdentifiableByDescription, OperationDelegateType: HTTP1OperationDelegate>(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, SmokeServerInvocationReporting<TraceContextType>,
                       @escaping (Result<OutputType, Swift.Error>) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)],
        operationDelegate: OperationDelegateType)
    where DefaultOperationDelegateType.RequestHeadType == OperationDelegateType.RequestHeadType,
    DefaultOperationDelegateType.TraceContextType == OperationDelegateType.TraceContextType,
    DefaultOperationDelegateType.ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        
        let handler = OperationHandler(
            serverName: serverName, operationIdentifer: operationIdentifer, reportingConfiguration: reportingConfiguration,
            inputProvider: operationDelegate.getInputForOperation,
            operation: operation,
            outputHandler: operationDelegate.handleResponseForOperation,
            allowedErrors: allowedErrors,
            operationDelegate: operationDelegate)
        
        addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, handler: handler)
    }
}
