// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// OperationHandler+withInputWithOutput.swift
// SmokeOperations
//

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)

import Foundation
import Logging
import Tracing

public extension OperationHandler {
    /**
      Initializer for async operation handler that has input returns
      a result body.
     
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
    init<InputType: Validatable, OutputType: Validatable, ErrorType: ErrorIdentifiableByDescription,
        OperationDelegateType: OperationDelegate>(
            serverName: String, operationIdentifer: OperationIdentifer,
            reportingConfiguration: SmokeReportingConfiguration<OperationIdentifer>,
            inputProvider: @escaping (RequestHeadType, Data?) throws -> InputType,
            operation: @escaping (InputType, ContextType) async throws -> OutputType,
            outputHandler: @escaping ((RequestHeadType, OutputType, ResponseHandlerType, SmokeInvocationContext<InvocationReportingType>) -> Void),
            allowedErrors: [(ErrorType, Int)],
            operationDelegate: OperationDelegateType)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    InvocationReportingType == OperationDelegateType.InvocationReportingType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        
        /**
         * The wrapped input handler takes the provided operation handler and wraps it so that if it
         * returns, the responseHandler is called with the result. If the provided operation
         * throws an error, the responseHandler is called with that error.
         */
        func wrappedInputHandler (input: InputType, requestHead: RequestHeadType, context: ContextType,
                                  responseHandler: OperationDelegateType.ResponseHandlerType,
                                  invocationContext: SmokeInvocationContext<InvocationReportingType>) {
            Task {
                await Self.withSpanContext(invocationContext: invocationContext) {
                    let handlerResult: WithOutputOperationHandlerResult<OutputType, ErrorType>
                    do {
                        let output = try await operation(input, context)
                        
                        handlerResult = .success(output)
                    } catch let smokeReturnableError as SmokeReturnableError {
                        handlerResult = .smokeReturnableError(smokeReturnableError, allowedErrors)
                    } catch SmokeOperationsError.validationError(reason: let reason) {
                        handlerResult = .validationError(reason)
                    } catch {
                        handlerResult = .internalServerError(error)
                    }
                    
                    OperationHandler.handleWithOutputOperationHandlerResult(
                        handlerResult: handlerResult,
                        operationDelegate: operationDelegate,
                        requestHead: requestHead,
                        responseHandler: responseHandler,
                        outputHandler: outputHandler,
                        invocationContext: invocationContext)
                }
            }
        }
        
        self.init(serverName: serverName,
                  operationIdentifer: operationIdentifer,
                  reportingConfiguration: reportingConfiguration,
                  inputHandler: wrappedInputHandler,
                  inputProvider: inputProvider,
                  operationDelegate: operationDelegate,
                  ignoreInvocationStrategy: true)
    }
}

#endif
