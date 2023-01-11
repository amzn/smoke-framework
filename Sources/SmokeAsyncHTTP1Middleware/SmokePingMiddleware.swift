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
import Logging

internal struct PingParameters {
    static let uri = "/ping"
    static let payload = "Ping completed.".data(using: .utf8) ?? Data()
}

public struct SmokePingMiddleware<Context>: _MiddlewareProtocol {
    public typealias Input = SmokeHTTP1Request
    public typealias Output = SmokeHTTP1Response<_AsyncLazySequence<[Data]>>
    
    public func handle(_ input: SmokeAsyncHTTP1Server.SmokeHTTP1Request, context: Context,
                       next: (SmokeHTTP1Request, Context) async throws -> SmokeHTTP1Response<_AsyncLazySequence<[Data]>>) async throws
    -> SmokeAsyncHTTP1Server.SmokeHTTP1Response<_AsyncLazySequence<[Data]>> {
        // this is the ping url
        if input.head.uri == PingParameters.uri {
            return SmokeHTTP1Response(status: .ok,
                                      body: (contentType: "text/plain", data: PingParameters.payload),
                                      additionalHeaders: [])
        }
        
        return try await next(input, context)
    }
}