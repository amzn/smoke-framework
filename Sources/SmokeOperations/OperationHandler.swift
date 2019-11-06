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
// OperationHandler.swift
// SmokeOperations
//

import Foundation
import LoggerAPI

/**
 Struct that handles serialization and de-serialization of request and response
 bodies from and to the shapes required by operation handlers.
 */
public struct OperationHandler<ContextType, RequestHeadType, ResponseHandlerType, OperationIdentifer: OperationIdentity> {
    public typealias OperationResultValidatableInputFunction<InputType: Validatable>
        = (_ input: InputType, _ requestHead: RequestHeadType, _ context: ContextType,
        _ responseHandler: ResponseHandlerType) -> ()
    public typealias OperationResultDataInputFunction
        = (_ requestHead: RequestHeadType, _ body: Data?, _ context: ContextType,
        _ responseHandler: ResponseHandlerType, _ invocationStrategy: InvocationStrategy) -> ()
    
    private let operationFunction: OperationResultDataInputFunction
    
    /**
     * Handle for an operation handler delegates the input to the wrapped handling function
     * constructed at initialization time.
     */
    public func handle(_ requestHead: RequestHeadType, body: Data?, withContext context: ContextType,
                       responseHandler: ResponseHandlerType, invocationStrategy: InvocationStrategy) {
        return operationFunction(requestHead, body, context, responseHandler, invocationStrategy)
    }
    
    private enum InputDecodeResult<InputType: Validatable> {
        case ok(input: InputType, inputHandler: OperationResultValidatableInputFunction<InputType>)
        case error(description: String, reportableType: String?)
        
        func handle<OperationDelegateType: OperationDelegate>(
                requestHead: RequestHeadType, context: ContextType,
                responseHandler: ResponseHandlerType, operationDelegate: OperationDelegateType)
            where RequestHeadType == OperationDelegateType.RequestHeadType,
            ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            switch self {
            case .error(description: let description, reportableType: let reportableType):
                if let reportableType = reportableType {
                    Log.error("DecodingError [\(reportableType): \(description)")
                } else {
                    Log.error("DecodingError: \(description)")
                }
                
                operationDelegate.handleResponseForDecodingError(
                    requestHead: requestHead,
                    message: description,
                    responseHandler: responseHandler)
            case .ok(input: let input, inputHandler: let inputHandler):
                do {
                    // attempt to validate the input
                    try input.validate()
                } catch SmokeOperationsError.validationError(let reason) {
                    Log.info("ValidationError: \(reason)")
                    
                    operationDelegate.handleResponseForValidationError(
                        requestHead: requestHead,
                        message: reason,
                        responseHandler: responseHandler)
                    return
                } catch {
                    Log.info("ValidationError: \(error)")
                    
                    operationDelegate.handleResponseForValidationError(
                        requestHead: requestHead,
                        message: nil,
                        responseHandler: responseHandler)
                    return
                }
                
                inputHandler(input, requestHead, context, responseHandler)
            }
        }
    }
    
    /**
     Initialier that accepts the function to use to handle this operation.
 
     - Parameters:
        - operationFunction: the function to use to handle this operation.
     */
    public init(operationIdentifer: OperationIdentifer,
                operationFunction: @escaping OperationResultDataInputFunction) {
        self.operationFunction = operationFunction
    }
    
    /**
     * Convenience initializer that incorporates decoding and validating
     */
    public init<InputType: Validatable, OperationDelegateType: OperationDelegate>(
        operationIdentifer: OperationIdentifer,
        inputHandler: @escaping OperationResultValidatableInputFunction<InputType>,
        inputProvider: @escaping (RequestHeadType, Data?) throws -> InputType,
        operationDelegate: OperationDelegateType)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        let newFunction: OperationResultDataInputFunction = { (requestHead, body, context, responseHandler, invocationStrategy) in
            let inputDecodeResult: InputDecodeResult<InputType>
            do {
                // decode the response within the event loop of the server to limit the number of request
                // `Data` objects that exist at single time to the number of threads in the event loop
                let input: InputType = try inputProvider(requestHead, body)
                
                inputDecodeResult = .ok(input: input, inputHandler: inputHandler)
            } catch DecodingError.keyNotFound(_, let context) {
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil)
            } catch DecodingError.valueNotFound(_, let context) {
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil)
            } catch DecodingError.typeMismatch(_, let context) {
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil)
            } catch DecodingError.dataCorrupted(let context) {
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil)
            } catch {
                let errorType = type(of: error)
                inputDecodeResult = .error(description: "\(error)", reportableType: "\(errorType)")
            }
            
            // continue the execution of the request according to the `invocationStrategy`
            // To avoid retaining the original body `Data` object, `body` should not be referenced in this
            // invocation.
            invocationStrategy.invoke {
                inputDecodeResult.handle(
                    requestHead: requestHead,
                    context: context,
                    responseHandler: responseHandler,
                    operationDelegate: operationDelegate)
            }
        }
        
        self.operationFunction = newFunction
    }
}
