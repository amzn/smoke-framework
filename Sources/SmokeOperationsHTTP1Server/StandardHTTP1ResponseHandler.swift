// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeOperationsHTTP1Server
//

import Foundation
import NIO
import NIOHTTP1
import SmokeOperationsHTTP1
import SmokeHTTP1
import Logging

private let timeIntervalToMilliseconds: Double = 1000

/**
 Handles the response to a HTTP request.
*/
public struct StandardHTTP1ResponseHandler<
        InvocationContext: HTTP1RequestInvocationContext>: ChannelHTTP1ResponseHandler, HTTP1ResponseHandler {
    let requestHead: HTTPRequestHead
    let keepAliveStatus: KeepAliveStatus
    let context: ChannelHandlerContext
    let smokeInwardsRequestContext: SmokeInwardsRequestContext?
    let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
    let onComplete: () -> ()
    
    public init(requestHead: HTTPRequestHead,
                keepAliveStatus: KeepAliveStatus,
                context: ChannelHandlerContext,
                wrapOutboundOut: @escaping (_ value: HTTPServerResponsePart) -> NIOAny,
                onComplete: @escaping () -> ()) {
        self.init(requestHead: requestHead,
                  keepAliveStatus: keepAliveStatus,
                  context: context,
                  smokeInwardsRequestContext: nil,
                  wrapOutboundOut: wrapOutboundOut,
                  onComplete: onComplete)
    }
    
    public init(requestHead: HTTPRequestHead,
                keepAliveStatus: KeepAliveStatus,
                context: ChannelHandlerContext,
                smokeInwardsRequestContext: SmokeInwardsRequestContext?,
                wrapOutboundOut: @escaping (_ value: HTTPServerResponsePart) -> NIOAny,
                onComplete: @escaping () -> ()) {
        self.requestHead = requestHead
        self.keepAliveStatus = keepAliveStatus
        self.context = context
        self.smokeInwardsRequestContext = smokeInwardsRequestContext
        self.wrapOutboundOut = wrapOutboundOut
        self.onComplete = onComplete
    }
    
    public func executeInEventLoop(invocationContext: InvocationContext, execute: @escaping () -> ()) {
        // if we are currently on a thread that can complete the response
        if context.eventLoop.inEventLoop {
            execute()
        } else {
            // otherwise execute on a thread that can
            context.eventLoop.execute {
                execute()
            }
        }
    }
    
    public func complete(invocationContext: InvocationContext, status: HTTPResponseStatus,
                         responseComponents: HTTP1ServerResponseComponents) {
        let bodySize = handleComplete(invocationContext: invocationContext, status: status,
                                      responseComponents: responseComponents, completeSilently: false)
        
        invocationContext.logger.trace("Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    public func completeInEventLoop(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                    responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.complete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    public func completeSilently(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                 responseComponents: HTTP1ServerResponseComponents) {
        let bodySize = handleComplete(invocationContext: invocationContext, status: status,
                                      responseComponents: responseComponents, completeSilently: true)
        
        invocationContext.logger.trace("Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    public func completeSilentlyInEventLoop(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                            responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.completeSilently(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    private func handleComplete(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                responseComponents: HTTP1ServerResponseComponents,
                                completeSilently: Bool) -> Int {
        var headers = HTTPHeaders()
        
        let buffer: ByteBuffer?
        let bodySize: Int
        
        // if there is a body
        if let body = responseComponents.body {
            let data = body.data
            // create a buffer for the body and copy the body into it
            var newBuffer = context.channel.allocator.buffer(capacity: data.count)
            newBuffer.writeBytes(data)
            
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
        
        // add any additional headers
        responseComponents.additionalHeaders.forEach { header in
            headers.add(name: header.0, value: header.1)
        }
        
        if !completeSilently {
            invocationContext.handleInwardsRequestComplete(httpHeaders: &headers, status: status, body: responseComponents.body)
        }
        
        if let smokeInwardsRequestContext = self.smokeInwardsRequestContext {
            let requestLatency = Date().timeIntervalSince(smokeInwardsRequestContext.requestStart).milliseconds
            let serviceCallCount = smokeInwardsRequestContext.retriableOutputRequestRecords.count
            let serviceCallLatency = smokeInwardsRequestContext.retriableOutputRequestRecords.reduce(0) { (retriableRequestSum, retriableRequestRecord) in
                return retriableRequestSum + retriableRequestRecord.outputRequests.reduce(0) { (requestSum, requestRecord) in
                    return requestSum + requestRecord.requestLatency.milliseconds
                }
            }
            let retryWaitLatency = smokeInwardsRequestContext.retryAttemptRecords.reduce(0) { (retryWaitSum, retryAttemptRecord) in
                return retryWaitSum + retryAttemptRecord.retryWait.milliseconds
            }
            let retriedServiceCalls = smokeInwardsRequestContext.retriableOutputRequestRecords.filter { requestRecord in
                return requestRecord.outputRequests.count > 1
            }
            let serviceOnlyLatency = requestLatency - serviceCallLatency - retryWaitLatency
            
            var logComponents: [String] = []
            
            if serviceCallCount == 0 {
                let logMessage = "Request completed in \(requestLatency) ms; (no service calls)."
                logComponents.append("\(logMessage)")
            } else {
                let logMessage = "Request completed in \(requestLatency) ms; "
                    + "\(serviceOnlyLatency) ms excluding service calls (there was \(serviceCallCount); "
                    + "\(serviceCallLatency) ms service call latency, \(retryWaitLatency) ms retry backoff)."
                logComponents.append("\(logMessage)")
            }
            
            if retriedServiceCalls.count == 1 {
                logComponents.append("1 outward service call was retried.")
            } else {
                logComponents.append("\(retriedServiceCalls.count) outward service calls were retried.")
            }
            
            invocationContext.logger.trace("\(logComponents.joined(separator: " "))")
            
            invocationContext.latencyTimer?.recordMilliseconds(requestLatency)
            invocationContext.serviceLatencyTimer?.recordMilliseconds(serviceOnlyLatency)
            invocationContext.outwardsServiceCallLatencySumTimer?.recordMilliseconds(serviceCallLatency)
            invocationContext.outwardsServiceCallRetryWaitSumTimer?.recordMilliseconds(retryWaitLatency)
            
            if status.code >= 200 && status.code < 300 {
                invocationContext.successCounter?.increment()
            } else if status.code >= 400 {
                if status.code < 500 {
                    invocationContext.failure4XXCounter?.increment()
                } else {
                    invocationContext.failure5XXCounter?.increment()
                }
                
                invocationContext.specificFailureStatusCounters?[status.code]?.increment()
            }
        }
        
        context.write(self.wrapOutboundOut(.head(HTTPResponseHead(version: requestHead.version,
                                                                  status: status,
                                                                  headers: headers))), promise: nil)
        
        // if there is a body, write it to the response
        if let buffer = buffer {
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        
        let promise: EventLoopPromise<Void>? = self.keepAliveStatus.state ? nil : context.eventLoop.makePromise()
        if let promise = promise {
            let currentContext = context
            // if keep alive is false, close the channel when the response end
            // has been written
            promise.futureResult.whenComplete { _ in
                currentContext.close(promise: nil)
            }
        }
        
        onComplete()
        
        // write the response end and flush
        context.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)),
                          promise: promise)
        
        return bodySize
    }
}

private extension TimeInterval {
    var milliseconds: Int {
        return Int(self * timeIntervalToMilliseconds)
    }
}
