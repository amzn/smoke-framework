//===----------------------------------------------------------------------===//
//
// This source file is part of the AsyncHTTPClient open source project
//
// Copyright (c) 2021 Apple Inc. and the AsyncHTTPClient project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of AsyncHTTPClient project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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

    @inlinable public init(
        method: HTTPMethod = .GET,
        version: HTTPVersion = .http1_1,
        uri: String,
        headers: HTTPHeaders = [:],
        body: Body = Body()
    ) {
        self.method = method
        self.version = version
        self.uri = uri
        self.headers = headers
        self.body = body
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
            @usableFromInline var storage: Storage.AsyncIterator

            @inlinable init(storage: Storage.AsyncIterator) {
                self.storage = storage
            }

            @inlinable public mutating func next() async throws -> ByteBuffer? {
                try await self.storage.next()
            }
        }

        @usableFromInline var storage: Storage

        @inlinable public func makeAsyncIterator() -> AsyncIterator {
            .init(storage: self.storage.makeAsyncIterator())
        }
    }
}

extension HTTPServerRequest.Body {
    @usableFromInline enum Storage: Sendable {
        case anyAsyncSequence(AnyAsyncSequence<ByteBuffer>)
    }
}

extension HTTPServerRequest.Body.Storage: AsyncSequence {
    @usableFromInline typealias Element = ByteBuffer

    @inlinable func makeAsyncIterator() -> AsyncIterator {
        switch self {
        case .anyAsyncSequence(let anyAsyncSequence):
            return .anyAsyncSequence(anyAsyncSequence.makeAsyncIterator())
        }
    }
}

extension HTTPServerRequest.Body.Storage {
    @usableFromInline enum AsyncIterator {
        case anyAsyncSequence(AnyAsyncSequence<ByteBuffer>.AsyncIterator)
    }
}

extension HTTPServerRequest.Body.Storage.AsyncIterator: AsyncIteratorProtocol {
    @inlinable mutating func next() async throws -> ByteBuffer? {
        switch self {
        case .anyAsyncSequence(var iterator):
            defer { self = .anyAsyncSequence(iterator) }
            return try await iterator.next()
        }
    }
}

extension HTTPServerRequest.Body {
    @usableFromInline init(_ storage: Storage) {
        self.storage = storage
    }

    public init() {
        self = .stream(EmptyCollection<ByteBuffer>().async)
    }

    @inlinable public static func stream<SequenceOfBytes>(
        _ sequenceOfBytes: SequenceOfBytes
    ) -> Self where SequenceOfBytes: AsyncSequence & Sendable, SequenceOfBytes.Element == ByteBuffer {
        self.init(.anyAsyncSequence(AnyAsyncSequence(sequenceOfBytes.singleIteratorPrecondition)))
    }

    public static func bytes(_ byteBuffer: ByteBuffer) -> Self {
        .stream(CollectionOfOne(byteBuffer).async)
    }
}
