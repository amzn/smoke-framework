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
//  JSONPayloadHTTP1OperationDelegate.swift
//  SmokeOperations
//

import Foundation
import SmokeHTTP1
import LoggerAPI

internal struct MimeTypes {
    static let json = "application/json"
}

internal struct JSONErrorEncoder: ErrorEncoder {
    public func encode<InputType>(_ input: InputType) throws -> Data where InputType: SmokeReturnableError {
        return JSONEncoder.encodePayload(payload: input,
                                         reason: input.description)
    }
}

/**
 Struct conforming to the OperationDelegate protocol that handles operations from HTTP1 requests with JSON encoded
 request and response payloads.
 */
public struct JSONPayloadHTTP1OperationDelegate: OperationDelegate {
    
    public init() {
        
    }
    
    public func getInputForOperation<InputType: Decodable>(request: SmokeHTTP1Request) throws -> InputType {
        if let body = request.body {
            return try JSONDecoder.getFrameworkDecoder().decode(InputType.self, from: body)
        } else {
            throw SmokeOperationsError.validationError(reason: "Input body expected; none found.")
        }
    }
    
    public func getOutputForOperation<OutputType: Encodable>(request: SmokeHTTP1Request, output: OutputType) throws -> Data? {
        return try JSONEncoder.getFrameworkEncoder().encode(output)
    }
    
    public func handleResponseForOperation<OutputType>(request: SmokeHTTP1Request, output: OutputType,
                                                       responseHandler: HTTP1ResponseHandler) where OutputType: Encodable {
        let encodedOutput: Data
        
        do {
            encodedOutput = try JSONEncoder.getFrameworkEncoder().encode(output)
        } catch {
            Log.error("Serialization error: unable to encode response: \(error)")
            
            handleResponseForInternalServerError(request: request, responseHandler: responseHandler)
            return
        }
        
        let body = (contentType: MimeTypes.json, data: encodedOutput)
        
        responseHandler.complete(status: .ok, body: body)
    }
    
    public func handleResponseForOperationWithNoOutput(request: SmokeHTTP1Request,
                                                       responseHandler: HTTP1ResponseHandler) {
        responseHandler.complete(status: .ok, body: nil)
    }
    
    public func handleResponseForOperationFailure(request: SmokeHTTP1Request,
                                                  operationFailure: OperationFailure,
                                                  responseHandler: HTTP1ResponseHandler) {
        let encodedOutput: Data
        
        do {
            encodedOutput = try operationFailure.error.encode(errorEncoder: JSONErrorEncoder())
        } catch {
            Log.error("Serialization error: unable to encode response: \(error)")
            
            handleResponseForInternalServerError(request: request, responseHandler: responseHandler)
            return
        }
        
        let body = (contentType: MimeTypes.json, data: encodedOutput)

        responseHandler.complete(status: .custom(code: UInt(operationFailure.code), reasonPhrase: operationFailure.error.description),
                                         body: body)
    }
    
    public func handleResponseForInternalServerError(request: SmokeHTTP1Request,
                                                     responseHandler: HTTP1ResponseHandler) {
        handleError(code: 500, reason: "InternalError", message: nil, responseHandler: responseHandler)
    }
    
    public func handleResponseForInvalidOperation(request: SmokeHTTP1Request,
                                                  message: String, responseHandler: HTTP1ResponseHandler) {
        handleError(code: 400, reason: "InvalidOperation", message: message, responseHandler: responseHandler)
    }
    
    public func handleResponseForDecodingError(request: SmokeHTTP1Request,
                                               message: String, responseHandler: HTTP1ResponseHandler) {
        handleError(code: 400, reason: "DecodingError", message: message, responseHandler: responseHandler)
    }
    
    public func handleResponseForValidationError(request: SmokeHTTP1Request,
                                                 message: String?, responseHandler: HTTP1ResponseHandler) {
        handleError(code: 400, reason: "ValidationError", message: message, responseHandler: responseHandler)
    }
    
    internal func handleError(code: Int,
                              reason: String,
                              message: String?,
                              responseHandler: HTTP1ResponseHandler) {
        let errorResult = SmokeOperationsErrorPayload(errorMessage: message)
        let encodedError = JSONEncoder.encodePayload(payload: errorResult,
                                                     reason: reason)
        
        let body = (contentType: MimeTypes.json, data: encodedError)

        responseHandler.complete(status: .custom(code: UInt(code), reasonPhrase: reason),
                                         body: body)
    }
}
