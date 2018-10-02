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
// OperationHandler.swift
// SmokeOperations
//

import Foundation
import LoggerAPI

/**
 Struct that handles serialization and de-serialization of request and response
 bodies from and to the shapes required by operation handlers.
 */
public struct OperationHandler<ContextType, OperationDelegateType: OperationDelegate> {
    public typealias OperationResultValidatableInputFunction<InputType: ValidatableCodable>
        = (_ input: InputType, _ request: OperationDelegateType.RequestType, _ context: ContextType,
           _ defaultOperationDelegate: OperationDelegateType, _ responseHandler: OperationDelegateType.ResponseHandlerType) -> ()
    public typealias OperationResultDataInputFunction
        = (_ request: OperationDelegateType.RequestType, _ context: ContextType,
           _ defaultOperationDelegate: OperationDelegateType, _ responseHandler: OperationDelegateType.ResponseHandlerType) -> ()
    
    private let operationFunction: OperationResultDataInputFunction
    
    /**
     * Handle for an operation handler delegates the input to the wrapped handling function
     * constructed at initialization time.
     */
    public func handle(_ request: OperationDelegateType.RequestType, withContext context: ContextType,
                       defaultOperationDelegate: OperationDelegateType,
                       responseHandler: OperationDelegateType.ResponseHandlerType) {
        return operationFunction(request, context, defaultOperationDelegate, responseHandler)
    }
    
    private enum InputDecodeResult<InputType> {
        case ok(input: InputType)
        case error(description: String, reportableType: String?)
    }
    
    /**
     Initialier that accepts the function to use to handle this operation.
 
     - Parameters:
        - operationFunction: the function to use to handle this operation.
     */
    public init(operationFunction: @escaping OperationResultDataInputFunction) {
        self.operationFunction = operationFunction
    }
    
    /**
     * Convenience initializer that incorporates decoding and validating
     */
    public init<InputType: ValidatableCodable>(
        _ inputHandler: @escaping OperationResultValidatableInputFunction<InputType>,
        operationDelegate: OperationDelegateType? = nil) {
        let newFunction: OperationResultDataInputFunction = { (request, context, defaultOperationDelegate, responseHandler) in
            let operationDelegateToUse = operationDelegate ?? defaultOperationDelegate
            
            let inputDecodeResult: InputDecodeResult<InputType>
            do {
                let input: InputType = try operationDelegateToUse.getInputForOperation(request: request)
                
                inputDecodeResult = .ok(input: input)
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
            
            switch inputDecodeResult {
            case .error(description: let description, reportableType: let reportableType):
                if let reportableType = reportableType {
                    Log.error("DecodingError [\(reportableType): \(description)")
                } else {
                    Log.error("DecodingError: \(description)")
                }
                
                operationDelegateToUse.handleResponseForDecodingError(request: request,
                                                                      message: description,
                                                                      responseHandler: responseHandler)
            case .ok(input: let input):
                do {
                    // attempt to validate the input
                    try input.validate()
                } catch SmokeOperationsError.validationError(let reason) {
                    Log.info("ValidationError: \(reason)")
                    
                    operationDelegateToUse.handleResponseForValidationError(request: request,
                                                                            message: reason,
                                                                            responseHandler: responseHandler)
                    return
                } catch {
                    Log.info("ValidationError: \(error)")
                    
                    operationDelegateToUse.handleResponseForValidationError(request: request,
                                                                            message: nil,
                                                                            responseHandler: responseHandler)
                    return
                }
                
                inputHandler(input, request, context, defaultOperationDelegate, responseHandler)
            }
        }
        
        self.operationFunction = newFunction
    }
}
