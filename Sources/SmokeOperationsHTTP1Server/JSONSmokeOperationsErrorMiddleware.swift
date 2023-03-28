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
// SmokeAsyncHTTP1Middleware
//

import Foundation
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import Logging
import SmokeOperations
import SmokeHTTP1ServerMiddleware

public struct JSONSmokeOperationsErrorMiddleware<Context: ContextWithMutableLogger>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = HTTPServerResponse
    
    public func handle(_ input: HTTPServerRequest, context: Context,
                       next: (HTTPServerRequest, Context) async throws -> HTTPServerResponse) async throws
    -> HTTPServerResponse {
        do {
            return try await next(input, context)
        } catch SmokeOperationsError.validationError(let reason) {
            let transform = JSONErrorResponseTransform<Context>(reason: "ValidationError", errorMessage: reason, status: .badRequest)
            return transform.transform(SmokeOperationsError.validationError(reason: reason), context: context)
        } catch SmokeOperationsError.invalidOperation(let reason) {
            let transform = JSONErrorResponseTransform<Context>(reason: "InvalidOperation", errorMessage: reason, status: .badRequest)
            return transform.transform(SmokeOperationsError.invalidOperation(reason: reason), context: context)
        }
    }
}
