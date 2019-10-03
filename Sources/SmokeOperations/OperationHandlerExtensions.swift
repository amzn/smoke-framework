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
// OperationHandlerExtensions.swift
// SmokeOperations
//

import Foundation
import LoggerAPI

/**
 Possible results of an operation that has no output.
 */
public enum NoOutputOperationHandlerResult<ErrorType: ErrorIdentifiableByDescription> {
    case internalServerError(Swift.Error)
    case validationError(String)
    case smokeReturnableError(SmokeReturnableError, [(ErrorType, Int)])
    case success
}

/**
 Possible results of an operation that has output.
 */
public enum WithOutputOperationHandlerResult<OutputType: Validatable,
        ErrorType: ErrorIdentifiableByDescription> {
    case internalServerError(Swift.Error)
    case validationError(String)
    case smokeReturnableError(SmokeReturnableError, [(ErrorType, Int)])
    case success(OutputType)
}

public extension OperationHandler {
    /**
     Generates the operation failure for a returnable error if the error is
     specified in the allowed errors array. Otherwise nil is returned.
 
     - Parameters:
        - error: The error to potentially encode as a response.
        - allowedErrors: the allowed errors to be encoded as a response. Each
          entry is a tuple specifying the error shape and the response code to use for
          returning that error.
     */
    static func fromSmokeReturnableError<ShapeType>(
        error: SmokeReturnableError,
        allowedErrors: [(ShapeType, Int)])
        -> OperationFailure? where ShapeType: ErrorIdentifiableByDescription {
            let requiredIdentity = error.description
            
            // get the code of the first entry in the allowedErrors array that has
            // the required identity.
            let code = allowedErrors.filter { entry in entry.0.description == requiredIdentity }
                .map { entry in entry.1 }
                .first
            
            if let code = code {
                return OperationFailure(code: code,
                                        error: error)
            }
            
            return nil
    }
    
    /**
     Calls the provided response handler appropriately for the provided
     NoOutputOperationHandlerResult.
 
     - Parameters:
        - handlerResult: the operation result indicating how the response handler
          should be called.
         - operationDelegate: the delegate for the current operation.
         - request: the current request.
         - responseHandler: the response handler to use.
     */
    static func handleNoOutputOperationHandlerResult<ErrorType, OperationDelegateType: OperationDelegate>(
        handlerResult: NoOutputOperationHandlerResult<ErrorType>,
        operationDelegate: OperationDelegateType,
        requestHead: OperationDelegateType.RequestHeadType,
        responseHandler: OperationDelegateType.ResponseHandlerType)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            switch handlerResult {
            case .internalServerError(let error):
                Log.error("Unexpected failure: \(error)")
                operationDelegate.handleResponseForInternalServerError(
                    requestHead: requestHead,
                    responseHandler: responseHandler)
            case .smokeReturnableError(let error, let allowedErrors):
                if let operationFailure =
                    OperationHandler.fromSmokeReturnableError(error: error,
                                                              allowedErrors: allowedErrors) {
                        operationDelegate.handleResponseForOperationFailure(
                            requestHead: requestHead,
                            operationFailure: operationFailure,
                            responseHandler: responseHandler)
                } else {
                    Log.error("Unexpected error type returned: \(error)")
                    operationDelegate.handleResponseForInternalServerError(
                        requestHead: requestHead,
                        responseHandler: responseHandler)
                }
            case .success:
                operationDelegate.handleResponseForOperationWithNoOutput(
                    requestHead: requestHead,
                    responseHandler: responseHandler)
            case .validationError(let reason):
                Log.info("ValidationError: \(reason)")
                operationDelegate.handleResponseForValidationError(
                    requestHead: requestHead,
                    message: reason,
                    responseHandler: responseHandler)
            }
    }
    
    /**
     Calls the provided response handler appropriately for the provided
     WithOutputOperationHandlerResult.
 
     - Parameters:
        - handlerResult: the operation result indicating how the response handler
          should be called.
         - operationDelegate: the delegate for the current operation.
         - request: the current request.
         - responseHandler: the response handler to use.
     */
    static func handleWithOutputOperationHandlerResult<OutputType, ErrorType, OperationDelegateType: OperationDelegate>(
        handlerResult: WithOutputOperationHandlerResult<OutputType, ErrorType>,
        operationDelegate: OperationDelegateType,
        requestHead: RequestHeadType,
        responseHandler: ResponseHandlerType,
        outputHandler: @escaping ((RequestHeadType, OutputType, ResponseHandlerType) -> Void))
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            switch handlerResult {
            case .internalServerError(let error):
                Log.error("Unexpected failure: \(error)")
                operationDelegate.handleResponseForInternalServerError(
                    requestHead: requestHead,
                    responseHandler: responseHandler)
            case .smokeReturnableError(let error, let allowedErrors):
                if let operationFailure =
                    OperationHandler.fromSmokeReturnableError(error: error,
                                                              allowedErrors: allowedErrors) {
                        operationDelegate.handleResponseForOperationFailure(
                            requestHead: requestHead,
                            operationFailure: operationFailure,
                            responseHandler: responseHandler)
                } else {
                    Log.error("Unexpected error type returned: \(error)")
                    operationDelegate.handleResponseForInternalServerError(
                        requestHead: requestHead,
                        responseHandler: responseHandler)
                }
            case .success(let output):
                do {
                    try output.validate()
                    
                    outputHandler(requestHead, output, responseHandler)
                } catch {
                    Log.error("Serialization error: unable to get response: \(error)")
                    
                    operationDelegate.handleResponseForInternalServerError(
                        requestHead: requestHead,
                        responseHandler: responseHandler)
                }
            case .validationError(let reason):
                Log.info("ValidationError: \(reason)")
                operationDelegate.handleResponseForValidationError(
                    requestHead: requestHead,
                    message: reason,
                    responseHandler: responseHandler)
            }
    }
}
