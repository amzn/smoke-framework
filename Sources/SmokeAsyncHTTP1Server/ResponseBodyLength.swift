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
// HTTP1RequestChannelHandler.swift
// SmokeAsyncHTTP1Server
//

import NIOCore

public enum ResponseBodyLength: Hashable, Sendable {
    /// size of the request body is not known before starting the response
    case unknown
    /// size of the response body is fixed and exactly `count` bytes
    case known(_ count: Int)
}
