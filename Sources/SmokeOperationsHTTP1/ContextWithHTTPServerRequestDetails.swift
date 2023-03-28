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
// ContextWithHTTPServerRequestDetails.swift
// SmokeOperationsHTTP1
//

import NIOHTTP1

/// A representation of an HTTP request with describing its body.
public struct HTTPServerRequestHead: Sendable {
    /// The HTTP method on which the request was received.
    public var method: HTTPMethod
    /// The HTTP method on which the request was received.
    public var version: HTTPVersion
    /// The uri of this HTTP request.
    public var uri: String
    /// The HTTP headers of this request.
    public var headers: HTTPHeaders
}

public protocol ContextWithHTTPServerRequestHead {

    var httpServerRequestHead: HTTPServerRequestHead { get }
}
