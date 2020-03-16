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
//  OperationHandler+nonblockingWithInputWithOutput.swift
//  SmokeOperations
//

import Foundation
import Logging

public extension OperationHandler {
    /**
       Initializer for non-blocking operation handler that has input
       returns a result body.
     
     - Parameters:
        - serverName: the name of the server this operation is part of.
        - operationIdentifer: the identifer for the operation being handled.
        - reportingConfiguration: the configuration for how operations on this server should be reported on.
        - inputProvider: function that obtains the input from the request.
        - operation: the handler method for the operation.
        - outputHandler: function that completes the response with the provided output.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: optionally an operation-specific delegate to use when
          handling the operation.
     */
    init<InputType: Validatable, OutputType: Validatable,
            ErrorType: ErrorIdentifiableByDescription, OperationDelegateType: OperationDelegate>(
            serverName: String, operationIdentifer: OperationIdentifer,
            reportingConfiguration: SmokeServerReportingConfiguration<OperationIdentifer>,
            inputProvider: @escaping (RequestHeadType, Data?) throws -> InputType,
            operation: @escaping ((InputType, ContextType, @escaping
                (Result<OutputType, Swift.Error>) -> Void) throws -> Void),
            outputHandler: @escaping ((RequestHeadType, OutputType, ResponseHandlerType, SmokeServerInvocationContext<TraceContextType>) -> Void),
            allowedErrors: [(ErrorType, Int)],
            operationDelegate: OperationDelegateType)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    TraceContextType == OperationDelegateType.TraceContextType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        
        /**
         * The wrapped input handler takes the provided operation handler and wraps it the responseHandler is
         * called with the result when the input handler's response handler is called. If the provided operation
         * provides an error, the responseHandler is called with that error.
         */
        let wrappedInputHandler = { (input: InputType, requestHead: RequestHeadType, context: ContextType,
            responseHandler: ResponseHandlerType, invocationContext: SmokeServerInvocationContext<TraceContextType>) in
            let handlerResult: WithOutputOperationHandlerResult<OutputType, ErrorType>?
            do {
                try operation(input, context) { result in
                    let asyncHandlerResult: WithOutputOperationHandlerResult<OutputType, ErrorType>
                    
                    switch result {
                    case .success(let result):
                        asyncHandlerResult = .success(result)
                    case .failure(let error):
                        if let smokeReturnableError = error as? SmokeReturnableError {
                            asyncHandlerResult = .smokeReturnableError(smokeReturnableError,
                                                                       allowedErrors)
                        } else if case SmokeOperationsError.validationError(reason: let reason) = error {
                            asyncHandlerResult = .validationError(reason)
                        } else {
                            asyncHandlerResult = .internalServerError(error)
                        }
                    }
                    
                    OperationHandler.handleWithOutputOperationHandlerResult(
                        handlerResult: asyncHandlerResult,
                        operationDelegate: operationDelegate,
                        requestHead: requestHead,
                        responseHandler: responseHandler,
                        outputHandler: outputHandler,
                        invocationContext: invocationContext)
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
                OperationHandler.handleWithOutputOperationHandlerResult(
                    handlerResult: handlerResult,
                    operationDelegate: operationDelegate,
                    requestHead: requestHead,
                    responseHandler: responseHandler,
                    outputHandler: outputHandler,
                    invocationContext: invocationContext)
            }
        }
        
        self.init(serverName: serverName,
                  operationIdentifer: operationIdentifer,
                  reportingConfiguration: reportingConfiguration,
                  inputHandler: wrappedInputHandler,
                  inputProvider: inputProvider,
                  operationDelegate: operationDelegate)
    }
}
