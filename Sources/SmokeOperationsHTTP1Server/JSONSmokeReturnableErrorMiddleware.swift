// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// JSONSmokeReturnableErrorMiddleware.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import Logging
import NIOHTTP1
import SmokeOperations
import SmokeHTTP1ServerMiddleware

public struct JSONSmokeReturnableErrorMiddleware<ErrorType: ErrorIdentifiableByDescription,
                                                 Context: ContextWithMutableLogger>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = HTTPServerResponse
    
    private let allowedErrors: [(ErrorType, Int)]
    
    public init(allowedErrors: [(ErrorType, Int)]) {
        self.allowedErrors = allowedErrors
    }
    
    public func handle(_ input: HTTPServerRequest, context: Context,
                       next: (HTTPServerRequest, Context) async throws -> HTTPServerResponse) async throws
    -> HTTPServerResponse {
        let operationFailure: OperationFailure
        do {
            return try await next(input, context)
        } catch let error as SmokeReturnableError {
            if let theOperationFailure = fromSmokeReturnableError(error: error) {
                operationFailure = theOperationFailure
            } else {
                context.logger?.error("Unexpected error type returned.",
                             metadata: ["cause": "\(String(describing: error))"])
                
                // rethrow error to be handled as an internal server error
                throw error
            }
        }
        
        let encodedOutput = try operationFailure.error.encode(errorEncoder: JSONErrorEncoder(), logger: context.logger)
        
        var response = HTTPServerResponse()
        response.body = HTTPServerResponse.Body.bytes(encodedOutput, contentType: MimeTypes.json)
        
        return response
    }
    
    /**
     Generates the operation failure for a returnable error if the error is
     specified in the allowed errors array. Otherwise nil is returned.
     
     - Parameters:
        - error: The error to potentially encode as a response.
        - allowedErrors: the allowed errors to be encoded as a response. Each
            entry is a tuple specifying the error shape and the response code to use for
            returning that error.
     */
    func fromSmokeReturnableError(
        error: SmokeReturnableError)
        -> OperationFailure? where ErrorType: ErrorIdentifiableByDescription {
            let requiredIdentity = error.description
            
            // get the code of the first entry in the allowedErrors array that has
            // the required identity.
            let code = self.allowedErrors.filter { entry in entry.0.description == requiredIdentity }
                .map { entry in entry.1 }
                .first
            
            if let code = code {
                return OperationFailure(code: code,
                                        error: error)
            }
            
            return nil
    }
}

internal struct JSONErrorEncoder: ErrorEncoder {
    public func encode<InputType>(_ input: InputType, logger: Logger?) throws -> Data where InputType: SmokeReturnableError {
        return JSONEncoder.encodePayload(payload: input, logger: logger,
                                         reason: input.description)
    }
}