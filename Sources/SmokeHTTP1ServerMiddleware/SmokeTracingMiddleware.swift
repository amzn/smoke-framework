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
// SmokeTracingMiddleware.swift
// SmokeAsyncHTTP1Middleware
//

import Foundation
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import Logging
import Tracing
import NIOHTTP1

public struct SmokeTracingMiddleware<Context: ContextWithMutableRequestId & ContextWithResponseWriter>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = Void
    
    private let serverName: String
    
    public init(serverName: String) {
        self.serverName = serverName
    }
    
    public func handle(_ input: HTTPServerRequest, context: Context,
                       next: (HTTPServerRequest, Context) async throws -> ()) async throws {
        var baggage = Baggage.current ?? .topLevel
        InstrumentationSystem.instrument.extract(input.headers, into: &baggage, using: HTTPHeadersExtractor())
        
        let span = InstrumentationSystem.tracer.startSpan(self.serverName, baggage: baggage, ofKind: .server)
        defer { span.end() }

        var attributes: SpanAttributes = [:]

        attributes["http.method"] = input.method.rawValue
        attributes["http.target"] = input.uri
        attributes["http.flavor"] = "\(input.version.major).\(input.version.minor)"
        // attributes["http.scheme"] = request.uri.scheme?.rawValue
        attributes["http.user_agent"] = input.headers.first(name: "user-agent")
        attributes["http.request_content_length"] = input.headers["content-length"].first


        span.attributes = attributes

        return try await Baggage.withValue(span.baggage) {
            do {
                try await next(input, context)
                let responseWriter = context.responseWriter

                let statusCode = await responseWriter.getStatus().code
                attributes["http.status_code"] = Int(statusCode)
                
                if case .known(let bodySize) = await responseWriter.getBodyLength() {
                    attributes["http.response_content_length"] = bodySize
                }
                span.attributes = attributes
                
                return
            } catch {
                // anything other than an internal server Error will have been caught at this point
                span.attributes["http.status_code"] = 500
                span.setStatus(.init(code: .error))
                
                span.recordError(error)
                throw error
            }
        }
    }
}

private struct HTTPHeadersExtractor: Extractor {
    func extract(key name: String, from headers: HTTPHeaders) -> String? {
        headers.first(name: name)
    }
}
