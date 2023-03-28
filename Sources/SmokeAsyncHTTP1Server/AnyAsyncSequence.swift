//===----------------------------------------------------------------------===//
//
// This source file is part of the AsyncHTTPClient open source project
//
// Copyright (c) 2022 Apple Inc. and the AsyncHTTPClient project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of AsyncHTTPClient project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@usableFromInline
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
struct AnyAsyncSequence<Element>: Sendable, AsyncSequence {
    @usableFromInline typealias AsyncIteratorNextCallback = () async throws -> Element?

    @usableFromInline struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline let nextCallback: AsyncIteratorNextCallback

        @inlinable init(nextCallback: @escaping AsyncIteratorNextCallback) {
            self.nextCallback = nextCallback
        }

        @inlinable mutating func next() async throws -> Element? {
            try await self.nextCallback()
        }
    }

    @usableFromInline var makeAsyncIteratorCallback: @Sendable () -> AsyncIteratorNextCallback

    @inlinable init<SequenceOfBytes>(
        _ asyncSequence: SequenceOfBytes
    ) where SequenceOfBytes: AsyncSequence & Sendable, SequenceOfBytes.Element == Element {
        self.makeAsyncIteratorCallback = {
            var iterator = asyncSequence.makeAsyncIterator()
            return {
                try await iterator.next()
            }
        }
    }

    @inlinable func makeAsyncIterator() -> AsyncIterator {
        .init(nextCallback: self.makeAsyncIteratorCallback())
    }
}
