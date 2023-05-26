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

public struct JSONSmokeOperationsErrorMiddleware<Context: ContextWithMutableLogger,
                                                 OutputWriter: HTTPServerResponseWriterProtocol>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = Void
    
    public func handle(_ input: Input,
                       outputWriter: OutputWriter,
                       context middlewareContext: Context,
                       next: (Input, OutputWriter, Context) async throws -> Void) async throws {
        do {
            return try await next(input, outputWriter, middlewareContext)
        } catch SmokeOperationsError.validationError(let reason) {
            try await JSONFormat.writeErrorResponse(reason: "ValidationError", errorMessage: reason,
                                                    status: .badRequest, logger: middlewareContext.logger,
                                                    outputWriter: outputWriter)
        } catch SmokeOperationsError.invalidOperation(let reason) {
            try await JSONFormat.writeErrorResponse(reason: "InvalidOperation", errorMessage: reason,
                                                    status: .badRequest, logger: middlewareContext.logger,
                                                    outputWriter: outputWriter)
        }
    }
}
