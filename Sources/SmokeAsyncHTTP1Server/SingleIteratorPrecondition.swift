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

import Atomics

/// Makes sure that a consumer of this `AsyncSequence` only calls `makeAsyncIterator()` at most once.
/// If `makeAsyncIterator()` is called multiple times, the program crashes.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
@usableFromInline struct SingleIteratorPrecondition<Base: AsyncSequence>: AsyncSequence {
    @usableFromInline let base: Base
    @usableFromInline let didCreateIterator: ManagedAtomic<Bool> = .init(false)
    @usableFromInline typealias Element = Base.Element
    @inlinable init(base: Base) {
        self.base = base
    }

    @inlinable func makeAsyncIterator() -> Base.AsyncIterator {
        precondition(
            self.didCreateIterator.exchange(true, ordering: .relaxed) == false,
            "makeAsyncIterator() is only allowed to be called at most once."
        )
        return self.base.makeAsyncIterator()
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension SingleIteratorPrecondition: @unchecked Sendable where Base: Sendable {}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension AsyncSequence {
    @inlinable var singleIteratorPrecondition: SingleIteratorPrecondition<Self> {
        .init(base: self)
    }
}
