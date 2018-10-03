// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// StandardHTTP1Response.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import LoggerAPI

/**
 Standard implementation of the HttpResponseHandler protocol to
 send the response to a HTTP request.
*/
struct StandardHTTP1ResponseHandler: HTTP1ResponseHandler {
    let requestHead: HTTPRequestHead
    let keepAliveStatus: KeepAliveStatus
    let context: ChannelHandlerContext
    let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
    
    func complete(status: HTTPResponseStatus,
                  body: (contentType: String, data: Data)?) {
        // if we are currently on a thread that can complete the response
        if context.eventLoop.inEventLoop {
            completeInEventLoop(status: status, body: body)
        } else {
            // otherwise execute on a thread that can
            context.eventLoop.execute {
                self.completeInEventLoop(status: status, body: body)
            }
        }
    }
    
    func completeInEventLoop(status: HTTPResponseStatus,
                             body: (contentType: String, data: Data)?) {
        let bodySize = handleComplete(status: status, body: body)
        
        Log.info("Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    func completeSilently(status: HTTPResponseStatus,
                          body: (contentType: String, data: Data)?) {
        let bodySize = handleComplete(status: status, body: body)
        
        Log.verbose("Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    private func handleComplete(status: HTTPResponseStatus,
                                body: (contentType: String, data: Data)?) -> Int {
        let ctx = context
        var headers = HTTPHeaders()
        
        let buffer: ByteBuffer?
        let bodySize: Int
        
        // if there is a body
        if let body = body {
            let data = body.data
            // create a buffer for the body and copy the body into it
            var newBuffer = ctx.channel.allocator.buffer(capacity: data.count)
            let array = [UInt8](data)
            newBuffer.write(bytes: array)
            
            buffer = newBuffer
            bodySize = data.count
            
            // add the content type header
            headers.add(name: HTTP1Headers.contentType, value: body.contentType)
        } else {
            buffer = nil
            bodySize = 0
        }
        
        // add the content length header and write the response head to the response
        headers.add(name: HTTP1Headers.contentLength, value: "\(bodySize)")
        ctx.write(self.wrapOutboundOut(.head(HTTPResponseHead(version: requestHead.version,
                                                              status: status,
                                                              headers: headers))), promise: nil)
        
        // if there is a body, write it to the response
        if let buffer = buffer {
            ctx.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        
        let promise: EventLoopPromise<Void>? = self.keepAliveStatus.state ? nil : ctx.eventLoop.newPromise()
        if let promise = promise {
            // if keep alive is false, close the channel when the response end
            // has been written
            promise.futureResult.whenComplete { ctx.close(promise: nil) }
        }
        
        // write the response end and flush
        ctx.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)),
                          promise: promise)
        
        return bodySize
    }
}
