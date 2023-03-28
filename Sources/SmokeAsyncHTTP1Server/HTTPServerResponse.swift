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

/// A representation of an HTTP response.
public struct HTTPServerResponse: Sendable {
    /// The status of the response.
    public var status: HTTPResponseStatus

    /// The response headers.
    public var headers: HTTPHeaders

    /// The response body, if any.
    public var body: Body?

    public init() {
        self.status = .ok
        self.headers = .init()
        self.body = .none
    }
}

extension HTTPServerResponse {
    /// An HTTP response body.
    ///
    /// This object encapsulates the difference between streamed HTTP response bodies and those bodies that
    /// are already entirely in memory.
    public struct Body: Sendable {
        @usableFromInline
        internal enum Mode: Sendable {
            /// - parameters:
            ///     - length: complete body length.
            ///     If `length` is `.known`, `nextBodyPart` is not allowed to produce more bytes than `length` defines.
            ///     - makeAsyncIterator: Creates a new async iterator under the hood and returns a function which will call `next()` on it.
            ///     The returned function then produce the next body buffer asynchronously.
            ///     We use a closure as an abstraction instead of an existential to enable specialization.
            case asyncSequence(
                length: ResponseBodyLength,
                contentType: String,
                makeAsyncIterator: @Sendable () -> ((ByteBufferAllocator) async throws -> ByteBuffer?)
            )
            /// - parameters:
            ///     - length: complete body length.
            ///     If `length` is `.known`, `nextBodyPart` is not allowed to produce more bytes than `length` defines.
            ///     - makeCompleteBody: function to produce the complete body.
            case sequence(
                length: ResponseBodyLength,
                contentType: String,
                makeCompleteBody: @Sendable (ByteBufferAllocator) -> ByteBuffer
            )
            case byteBuffer(bytes: ByteBuffer, contentType: String)
        }

        @usableFromInline
        internal var mode: Mode

        @inlinable
        internal init(_ mode: Mode) {
            self.mode = mode
        }
    }
}

extension HTTPServerResponse.Body {
    /// Create an ``HTTPServerResponse/Body-swift.struct`` from a `ByteBuffer`.
    ///
    /// - parameter byteBuffer: The bytes of the body.
    public static func bytes(_ byteBuffer: ByteBuffer,
                             contentType: String) -> Self {
        self.init(.byteBuffer(bytes: byteBuffer, contentType: contentType))
    }

    /// Create an ``HTTPServerResponse/Body-swift.struct`` from a `RandomAccessCollection` of bytes.
    ///
    /// This construction will flatten the bytes into a `ByteBuffer`. As a result, the peak memory
    /// usage of this construction will be double the size of the original collection. The construction
    /// of the `ByteBuffer` will be delayed until it's needed.
    ///
    /// - parameter bytes: The bytes of the response body.
    @inlinable
    @preconcurrency
    public static func bytes<Bytes: RandomAccessCollection & Sendable>(
        _ bytes: Bytes,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        Self._bytes(bytes, contentType: contentType)
    }

    @inlinable
    static func _bytes<Bytes: RandomAccessCollection>(
        _ bytes: Bytes,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        self.init(.sequence(
            length: .known(bytes.count),
            contentType: contentType
        ) { allocator in
            if let buffer = bytes.withContiguousStorageIfAvailable({ allocator.buffer(bytes: $0) }) {
                // fastpath
                return buffer
            }
            // potentially really slow path
            return allocator.buffer(bytes: bytes)
        })
    }

    /// Create an ``HTTPServerResponse/Body-swift.struct`` from a `Sequence` of bytes.
    ///
    /// This construction will flatten the bytes into a `ByteBuffer`. As a result, the peak memory
    /// usage of this construction will be double the size of the original collection. The construction
    /// of the `ByteBuffer` will be delayed until it's needed.
    ///
    /// Caution should be taken with this method to ensure that the `length` is correct. Incorrect lengths
    /// will cause unnecessary runtime failures. Setting `length` to ``Length/unknown`` will trigger the upload
    /// to use `chunked` `Transfer-Encoding`, while using ``Length/known(_:)`` will use `Content-Length`.
    ///
    /// - parameters:
    ///     - bytes: The bytes of the response body.
    ///     - length: The length of the response body.
    @inlinable
    @preconcurrency
    public static func bytes<Bytes: Sequence & Sendable>(
        _ bytes: Bytes,
        length: Length,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        Self._bytes(bytes, length: length, contentType: contentType)
    }

    @inlinable
    static func _bytes<Bytes: Sequence>(
        _ bytes: Bytes,
        length: Length,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        self.init(.sequence(
            length: length.storage,
            contentType: contentType
        ) { allocator in
            if let buffer = bytes.withContiguousStorageIfAvailable({ allocator.buffer(bytes: $0) }) {
                // fastpath
                return buffer
            }
            // potentially really slow path
            return allocator.buffer(bytes: bytes)
        })
    }

    /// Create an ``HTTPServerResponse/Body-swift.struct`` from a `Collection` of bytes.
    ///
    /// This construction will flatten the bytes into a `ByteBuffer`. As a result, the peak memory
    /// usage of this construction will be double the size of the original collection. The construction
    /// of the `ByteBuffer` will be delayed until it's needed.
    ///
    /// Caution should be taken with this method to ensure that the `length` is correct. Incorrect lengths
    /// will cause unnecessary runtime failures. Setting `length` to ``Length/unknown`` will trigger the upload
    /// to use `chunked` `Transfer-Encoding`, while using ``Length/known(_:)`` will use `Content-Length`.
    ///
    /// - parameters:
    ///     - bytes: The bytes of the response body.
    ///     - length: The length of the response body.
    @inlinable
    @preconcurrency
    public static func bytes<Bytes: Collection & Sendable>(
        _ bytes: Bytes,
        length: Length,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        Self._bytes(bytes, length: length, contentType: contentType)
    }

    @inlinable
    static func _bytes<Bytes: Collection>(
        _ bytes: Bytes,
        length: Length,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        self.init(.sequence(
            length: length.storage,
            contentType: contentType
        ) { allocator in
            if let buffer = bytes.withContiguousStorageIfAvailable({ allocator.buffer(bytes: $0) }) {
                // fastpath
                return buffer
            }
            // potentially really slow path
            return allocator.buffer(bytes: bytes)
        })
    }

    /// Create an ``HTTPServerResponse/Body-swift.struct`` from an `AsyncSequence` of `ByteBuffer`s.
    ///
    /// This construction will stream the upload one `ByteBuffer` at a time.
    ///
    /// Caution should be taken with this method to ensure that the `length` is correct. Incorrect lengths
    /// will cause unnecessary runtime failures. Setting `length` to ``Length/unknown`` will trigger the upload
    /// to use `chunked` `Transfer-Encoding`, while using ``Length/known(_:)`` will use `Content-Length`.
    ///
    /// - parameters:
    ///     - sequenceOfBytes: The bytes of the response body.
    ///     - length: The length of the response body.
    @inlinable
    @preconcurrency
    public static func stream<SequenceOfBytes: AsyncSequence & Sendable>(
        _ sequenceOfBytes: SequenceOfBytes,
        length: Length,
        contentType: String
    ) -> Self where SequenceOfBytes.Element == ByteBuffer {
        Self._stream(sequenceOfBytes, length: length, contentType: contentType)
    }

    @inlinable
    static func _stream<SequenceOfBytes: AsyncSequence>(
        _ sequenceOfBytes: SequenceOfBytes,
        length: Length,
        contentType: String
    ) -> Self where SequenceOfBytes.Element == ByteBuffer {
        let body = self.init(.asyncSequence(length: length.storage, contentType: contentType) {
            var iterator = sequenceOfBytes.makeAsyncIterator()
            return { _ -> ByteBuffer? in
                try await iterator.next()
            }
        })
        return body
    }

    /// Create an ``HTTPServerResponse/Body-swift.struct`` from an `AsyncSequence` of bytes.
    ///
    /// This construction will consume 1kB chunks from the `Bytes` and send them at once. This optimizes for
    /// `AsyncSequence`s where larger chunks are buffered up and available without actually suspending, such
    /// as those provided by `FileHandle`.
    ///
    /// Caution should be taken with this method to ensure that the `length` is correct. Incorrect lengths
    /// will cause unnecessary runtime failures. Setting `length` to ``Length/unknown`` will trigger the upload
    /// to use `chunked` `Transfer-Encoding`, while using ``Length/known(_:)`` will use `Content-Length`.
    ///
    /// - parameters:
    ///     - bytes: The bytes of the response body.
    ///     - length: The length of the response body.
    @inlinable
    @preconcurrency
    public static func stream<Bytes: AsyncSequence & Sendable>(
        _ bytes: Bytes,
        length: Length,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        Self._stream(bytes, length: length, contentType: contentType)
    }

    @inlinable
    static func _stream<Bytes: AsyncSequence>(
        _ bytes: Bytes,
        length: Length,
        contentType: String
    ) -> Self where Bytes.Element == UInt8 {
        let body = self.init(.asyncSequence(length: length.storage, contentType: contentType) {
            var iterator = bytes.makeAsyncIterator()
            return { allocator -> ByteBuffer? in
                var buffer = allocator.buffer(capacity: 1024) // TODO: Magic number
                while buffer.writableBytes > 0, let byte = try await iterator.next() {
                    buffer.writeInteger(byte)
                }
                if buffer.readableBytes > 0 {
                    return buffer
                }
                return nil
            }
        })
        return body
    }
}

extension HTTPServerResponse.Body {
    internal var contentType: String {
        switch self.mode {
        case .byteBuffer(_, let contentType): return contentType
        case .sequence(_, let contentType, _): return contentType
        case .asyncSequence(_, let contentType, _): return contentType
        }
    }
}

extension HTTPServerResponse.Body {
    internal var size: Int? {
        let responseBodyLength: ResponseBodyLength
        switch self.mode {
        case .byteBuffer(let buffer, _): responseBodyLength = .known(buffer.readableBytes)
        case .sequence(let length, _, _): responseBodyLength = length
        case .asyncSequence(let length, _, _): responseBodyLength = length
        }
        
        switch responseBodyLength {
        case .unknown:
            return nil
        case .known(let size):
            return size
        }
    }
}

extension HTTPServerResponse.Body {
    /// The length of a HTTP response body.
    public struct Length: Sendable {
        /// The size of the response body is not known before starting the response
        public static let unknown: Self = .init(storage: .unknown)

        /// The size of the response body is known and exactly `count` bytes
        public static func known(_ count: Int) -> Self {
            .init(storage: .known(count))
        }

        @usableFromInline
        internal var storage: ResponseBodyLength
    }
}
