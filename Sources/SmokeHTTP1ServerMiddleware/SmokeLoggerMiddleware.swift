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
// SmokeLoggerMiddleware.swift
// SmokeAsyncHTTP1Middleware
//

import Foundation
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import Logging

public struct SmokeLoggerMiddleware<Context: ContextWithMutableLogger & ContextWithMutableRequestId, OutputWriter>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    
    public init() {
        
    }
    
    public func handle(_ input: Input,
                       outputWriter: OutputWriter,
                       context: Context,
                       next: (Input, OutputWriter, Context) async throws -> Void) async throws {
        var newLogger = Logger(label: "com.amazon.SmokeFramework.request")
        
        if let internalRequestId = context.internalRequestId {
            newLogger[metadataKey: "internalRequestId"] = "\(internalRequestId)"
        }
        
        var updatedContext = context
        updatedContext.logger = newLogger
        
        try await next(input, outputWriter, updatedContext)
    }
}
