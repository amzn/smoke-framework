// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// OperationHandler+nonblockingWithInputNoOutput.swift
// SmokeOperations
//

import Foundation
import LoggerAPI
import NIOHTTP1

public extension OperationHandler {
    /**
       Initializer for non-blocking operation handler that has input
       returns a result with an empty body.
     
     - Parameters:
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: optionally an operation-specific delegate to use when
          handling the operation
     */
    public init<InputType: ValidatableCodable, ErrorType: ErrorIdentifiableByDescription>(
            operation: @escaping ((InputType, ContextType, @escaping (Swift.Error?) -> ()) throws -> ()),
            allowedErrors: [(ErrorType, Int)],
            operationDelegate: OperationDelegateType? = nil) {
        
        /**
         * The wrapped input handler takes the provided operation handler and wraps it the responseHandler is
         * called to indicate success when the input handler's response handler is called. If the provided operation
         * provides an error, the responseHandler is called with that error.
         */
        let wrappedInputHandler = { (input: InputType, request: OperationDelegateType.RequestType, context: ContextType,
                                     defaultOperationDelegate: OperationDelegateType,
                                     responseHandler: OperationDelegateType.ResponseHandlerType) in
            let operationDelegateToUse = operationDelegate ?? defaultOperationDelegate

            let handlerResult: NoOutputOperationHandlerResult<ErrorType>?
            do {
                try operation(input, context) { error in
                    let asyncHandlerResult: NoOutputOperationHandlerResult<ErrorType>
                    
                    if let error = error {
                        if let smokeReturnableError = error as? SmokeReturnableError {
                            asyncHandlerResult = .smokeReturnableError(smokeReturnableError,
                                                                       allowedErrors)
                        } else if case SmokeOperationsError.validationError(reason: let reason) = error {
                            asyncHandlerResult = .validationError(reason)
                        } else {
                            asyncHandlerResult = .internalServerError(error)
                        }
                    } else {
                        asyncHandlerResult = .success
                    }
                    
                    OperationHandler.handleNoOutputOperationHandlerResult(
                        handlerResult: asyncHandlerResult,
                        operationDelegate: operationDelegateToUse,
                        request: request,
                        responseHandler: responseHandler)
                }
                
                // no immediate result
                handlerResult = nil
            } catch let smokeReturnableError as SmokeReturnableError {
                handlerResult = .smokeReturnableError(smokeReturnableError, allowedErrors)
            } catch SmokeOperationsError.validationError(reason: let reason) {
                handlerResult = .validationError(reason)
            } catch {
                handlerResult = .internalServerError(error)
            }
            
            // if this handler is throwing an error immediately
            if let handlerResult = handlerResult {
                OperationHandler.handleNoOutputOperationHandlerResult(
                    handlerResult: handlerResult,
                    operationDelegate: operationDelegateToUse,
                    request: request,
                    responseHandler: responseHandler)
            }
        }
        
        self.init(wrappedInputHandler)
    }
}

public extension SmokeHTTP1HandlerSelector {
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: optionally an operation-specific delegate to use when
          handling the operation
     */
    public mutating func addHandlerForUri<InputType: ValidatableCodable, ErrorType: ErrorIdentifiableByDescription>(
        _ uri: String,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, @escaping (Swift.Error?) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)],
        operationDelegate: OperationDelegateType? = nil) {
            let handler = OperationHandler(operation: operation,
                                           allowedErrors: allowedErrors,
                                           operationDelegate: operationDelegate)
        
        addHandlerForUri(uri, httpMethod: httpMethod, handler: handler)
    }
}
