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
public struct OperationHandler<ContextType, RequestType, ResponseHandlerType> {
    public typealias OperationResultValidatableInputFunction<InputType: Validatable>
        = (_ input: InputType, _ request: RequestType, _ context: ContextType,
        _ responseHandler: ResponseHandlerType) -> ()
    public typealias OperationResultDataInputFunction
        = (_ request: RequestType, _ context: ContextType,
        _ responseHandler: ResponseHandlerType) -> ()
    
    private let operationFunction: OperationResultDataInputFunction
    
    /**
     * Handle for an operation handler delegates the input to the wrapped handling function
     * constructed at initialization time.
     */
    public func handle(_ request: RequestType, withContext context: ContextType,
                       responseHandler: ResponseHandlerType) {
        return operationFunction(request, context, responseHandler)
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
    public init<InputType: Validatable, OperationDelegateType: OperationDelegate>(
        inputHandler: @escaping OperationResultValidatableInputFunction<InputType>,
        inputProvider: @escaping (RequestType) throws -> InputType,
        operationDelegate: OperationDelegateType)
    where RequestType == OperationDelegateType.RequestType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        let newFunction: OperationResultDataInputFunction = { (request, context, responseHandler) in
            let inputDecodeResult: InputDecodeResult<InputType>
            do {
                let input: InputType = try inputProvider(request)
                
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
                
                operationDelegate.handleResponseForDecodingError(
                    request: request,
                    message: description,
                    responseHandler: responseHandler)
            case .ok(input: let input):
                do {
                    // attempt to validate the input
                    try input.validate()
                } catch SmokeOperationsError.validationError(let reason) {
                    Log.info("ValidationError: \(reason)")
                    
                    operationDelegate.handleResponseForValidationError(
                        request: request,
                        message: reason,
                        responseHandler: responseHandler)
                    return
                } catch {
                    Log.info("ValidationError: \(error)")
                    
                    operationDelegate.handleResponseForValidationError(
                        request: request,
                        message: nil,
                        responseHandler: responseHandler)
                    return
                }
                
                inputHandler(input, request, context, responseHandler)
            }
        }
        
        self.operationFunction = newFunction
    }
}
