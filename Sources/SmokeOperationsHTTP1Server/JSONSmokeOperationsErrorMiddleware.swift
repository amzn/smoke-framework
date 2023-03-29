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
// JSONSmokeOperationsErrorMiddleware.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import Logging
import NIOHTTP1
import SmokeOperations
import SmokeHTTP1ServerMiddleware

public struct JSONSmokeOperationsErrorMiddleware<Context: ContextWithMutableLogger>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = HTTPServerResponse
    
    public func handle(_ input: HTTPServerRequest, context middlewareContext: Context,
                       next: (HTTPServerRequest, Context) async throws -> HTTPServerResponse) async throws
    -> HTTPServerResponse {
        do {
            return try await next(input, middlewareContext)
        } catch SmokeOperationsError.validationError(let reason) {
            return JSONFormat.getErrorResponse(reason: "ValidationError", errorMessage: reason,
                                               status: .badRequest, logger: middlewareContext.logger)
        } catch SmokeOperationsError.invalidOperation(let reason) {
            return JSONFormat.getErrorResponse(reason: "InvalidOperation", errorMessage: reason,
                                               status: .badRequest, logger: middlewareContext.logger)
        }
    }
}
