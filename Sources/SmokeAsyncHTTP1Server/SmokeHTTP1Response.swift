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
// SmokeHTTP1Response.swift
// SmokeAsyncHTTP1Server
//

import Foundation
import NIO
import NIOHTTP1

public struct SmokeHTTP1Response<BodyStreamType: AsyncSequence> where BodyStreamType.Element == Data {
    public let status: HTTPResponseStatus
    public let body: (contentType: String, stream: BodyStreamType, size: Int?)?
    public let additionalHeaders: [(String, String)]
    
    public init(status: HTTPResponseStatus,
                body: (contentType: String, stream: BodyStreamType, size: Int?)?,
                additionalHeaders: [(String, String)]) {
        self.status = status
        self.body = body
        self.additionalHeaders = additionalHeaders
    }
    
    public init(status: HTTPResponseStatus,
                body: (contentType: String, data: Data)?,
                additionalHeaders: [(String, String)])
    where BodyStreamType == _AsyncLazySequence<[Data]> {
        self.status = status
        self.additionalHeaders = additionalHeaders
        
        if let body = body {
            let stream = _AsyncLazySequence([body.data])
            self.body = (contentType: body.contentType, stream: stream, size: body.data.count)
        } else {
            self.body = nil
        }
    }
}


// From https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncLazySequence.swift
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception

@frozen
public struct _AsyncLazySequence<Base: Sequence>: AsyncSequence {
  public typealias Element = Base.Element
  
  @frozen
  public struct Iterator: AsyncIteratorProtocol {
    @usableFromInline
    var iterator: Base.Iterator?
    
    @usableFromInline
    init(_ iterator: Base.Iterator) {
      self.iterator = iterator
    }
    
    @inlinable
    public mutating func next() async -> Base.Element? {
      if !Task.isCancelled, let value = iterator?.next() {
        return value
      } else {
        iterator = nil
        return nil
      }
    }
  }
  
  @usableFromInline
  let base: Base
  
  @usableFromInline
  init(_ base: Base) {
    self.base = base
  }
  
  @inlinable
  public func makeAsyncIterator() -> Iterator {
    Iterator(base.makeIterator())
  }
}

extension _AsyncLazySequence: Sendable where Base: Sendable { }
