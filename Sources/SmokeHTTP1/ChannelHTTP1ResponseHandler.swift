// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// ChannelHTTP1ResponseHandler.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import SmokeOperations

/**
 Extension of the `HTTP1ResponseHandler` protocol; adds an initializer requirement to create
 an instance from the `HTTP1ChannelInboundHandler`.
 */
public protocol ChannelHTTP1ResponseHandler : HTTP1ResponseHandler where InvocationContext: HTTP1RequestInvocationContext {
    
    /**
     Initializer.
     
     - Parameters:
         - requestHead: the head of the request that this handler will respond to.
         - keepAliveStatus: if the request should be kept alive.
         - context: the `ChannelHandlerContext` associated with the response.
         - wrapOutboundOut: helper function to prepare a `HTTPServerResponsePart` for transmission on the channel.
         - onComplete: to be called when the response has been sent on the channel.
     */
    init(requestHead: HTTPRequestHead,
         keepAliveStatus: KeepAliveStatus,
         context: ChannelHandlerContext,
         wrapOutboundOut: @escaping (_ value: HTTPServerResponsePart) -> NIOAny,
         onComplete: @escaping () -> ())
    
}
