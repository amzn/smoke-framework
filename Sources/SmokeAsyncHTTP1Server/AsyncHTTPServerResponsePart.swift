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
// SendableHTTPServerResponsePart.swift
// SmokeAsyncHTTP1Server
//

import NIOCore
import NIOHTTP1

/// Response HTTPPart that is compatible with the AsyncHTTP1Server
public typealias AsyncHTTPServerResponsePart = HTTPPart<HTTPResponseHead, ByteBuffer>

/**
 Channel handler to converter
 */
final class HTTPServerResponsePartConverterHandler: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = AsyncHTTPServerResponsePart
    typealias OutboundOut = HTTPServerResponsePart

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = unwrapOutboundIn(data)
        switch part {
        case .head(let head):
            context.write(self.wrapOutboundOut(.head(head)), promise: promise)
        case .body(let buffer):
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
        case .end:
            context.write(self.wrapOutboundOut(.end(nil)), promise: promise)
        }
    }
    
    func flush(context: ChannelHandlerContext) {
        // just propagate the flush
        context.flush()
    }
}
