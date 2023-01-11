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
// SmokeHTTP1Request.swift
// SmokeAsyncHTTP1Server
//

import Foundation
import NIO
import NIOHTTP1

public typealias SmokeHTTP1Request = GenericSmokeHTTP1Request<AsyncStream<Data>>

public struct GenericSmokeHTTP1Request<BodyStreamType: AsyncSequence> where BodyStreamType.Element == Data {
    public let head: HTTPRequestHead
    public let bodyStream: BodyStreamType
    
    public init(head: HTTPRequestHead, bodyStream: BodyStreamType) {
        self.head = head
        self.bodyStream = bodyStream
    }
}
