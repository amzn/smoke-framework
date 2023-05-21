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
// SmokePingMiddleware.swift
// SmokeAsyncHTTP1Middleware
//

import Foundation
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import Logging

internal struct PingParameters {
    static let uri = "/ping"
    static let payload = "Ping completed.".data(using: .utf8) ?? Data()
    static let contentType = "text/plain"
}

public struct SmokePingMiddleware<Context: ContextWithResponseWriter>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = Void
    
    public init() {
        
    }
    
    public func handle(_ input: HTTPServerRequest, context: Context,
                       next: (HTTPServerRequest, Context) async throws -> ()) async throws {
        // this is the ping url
        if input.uri == PingParameters.uri {
            let responseWriter = context.responseWriter
            
            await responseWriter.setContentType(PingParameters.contentType)
            try await responseWriter.commitAndCompleteWith(PingParameters.payload)
            
            return
        }
        
        return try await next(input, context)
    }
}
