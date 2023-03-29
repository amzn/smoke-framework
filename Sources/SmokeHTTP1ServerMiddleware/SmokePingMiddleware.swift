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
    static let responseBody = HTTPServerResponse.Body.bytes(payload, contentType: "text/plain")
}

public struct SmokePingMiddleware<Context>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = HTTPServerResponse
    
    public init() {
        
    }
    
    public func handle(_ input: HTTPServerRequest, context: Context,
                       next: (HTTPServerRequest, Context) async throws -> HTTPServerResponse) async throws
    -> HTTPServerResponse {
        // this is the ping url
        if input.uri == PingParameters.uri {
            var response = HTTPServerResponse()
            response.body = PingParameters.responseBody
            
            return response
        }
        
        return try await next(input, context)
    }
}
