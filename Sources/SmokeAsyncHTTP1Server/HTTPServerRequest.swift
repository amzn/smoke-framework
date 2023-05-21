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
// HTTPServerRequest.swift
// SmokeAsyncHTTP1Server
//

import NIOCore
import NIOHTTP1
import AsyncAlgorithms

/// A representation of an HTTP request..
public struct HTTPServerRequest: Sendable {
    /// The HTTP method on which the request was received.
    public var method: HTTPMethod
    
    /// The HTTP method on which the request was received.
    public var version: HTTPVersion
    
    /// The uri of this HTTP request.
    public var uri: String

    /// The HTTP headers of this request.
    public var headers: HTTPHeaders

    /// The body of this HTTP request.
    public var body: Body

    init(
        method: HTTPMethod = .GET,
        version: HTTPVersion = .http1_1,
        uri: String,
        headers: HTTPHeaders = [:],
        bodyChannel: AsyncThrowingChannel<ByteBuffer, Error>
    ) {
        self.method = method
        self.version = version
        self.uri = uri
        self.headers = headers
        self.body = .init(underlyingChannel: bodyChannel)
    }
}

extension HTTPServerRequest {
    /// A representation of the request body for an HTTP request.
    ///
    /// The body is streamed as an `AsyncSequence` of `ByteBuffer`, where each `ByteBuffer` contains
    /// an arbitrarily large chunk of data. The boundaries between `ByteBuffer` objects in the sequence
    /// are entirely synthetic and have no semantic meaning.
    public struct Body: AsyncSequence, Sendable {
        public typealias Element = ByteBuffer
        public struct AsyncIterator: AsyncIteratorProtocol {
            @usableFromInline var underlyingIterator: AsyncThrowingChannel<ByteBuffer, Error>.AsyncIterator

            @inlinable init(underlyingIterator: AsyncThrowingChannel<ByteBuffer, Error>.AsyncIterator) {
                self.underlyingIterator = underlyingIterator
            }

            @inlinable public mutating func next() async throws -> ByteBuffer? {
                try await self.underlyingIterator.next()
            }
        }

        @usableFromInline var underlyingChannel: AsyncThrowingChannel<ByteBuffer, Error>

        @inlinable public func makeAsyncIterator() -> AsyncIterator {
            return .init(underlyingIterator: self.underlyingChannel.makeAsyncIterator())
        }
    }
}
