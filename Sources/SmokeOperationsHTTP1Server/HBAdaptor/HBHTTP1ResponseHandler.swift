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
// HBHTTP1ResponseHandler.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import NIO
import NIOHTTP1
import SmokeOperationsHTTP1
import SmokeHTTP1
import Logging
import HummingbirdCore

private let timeIntervalToMilliseconds: Double = 1000

/**
 Handles the response to a HTTP request.
*/
public struct HBHTTP1ResponseHandler<
        InvocationContext: HTTP1RequestInvocationContext>: HTTP1ResponseHandler {
    let requestHead: HTTPRequestHead
    let context: ChannelHandlerContext
    let smokeInwardsRequestContext: SmokeInwardsRequestContext?
    let onComplete: (Result<HBHTTPResponse, Error>) -> Void

    public init(requestHead: HTTPRequestHead,
                context: ChannelHandlerContext,
                smokeInwardsRequestContext: SmokeInwardsRequestContext?,
                onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
        self.requestHead = requestHead
        self.context = context
        self.smokeInwardsRequestContext = smokeInwardsRequestContext
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
        handleComplete(invocationContext: invocationContext, status: status,
                       responseComponents: responseComponents, reportRequest: true)
    }
    
    public func completeInEventLoop(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                    responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.complete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    public func completeSilently(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                 responseComponents: HTTP1ServerResponseComponents) {
        handleComplete(invocationContext: invocationContext, status: status,
                       responseComponents: responseComponents, reportRequest: false)
    }
    
    public func completeSilentlyInEventLoop(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                            responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.completeSilently(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    private func reportRequestOnComplete(smokeInwardsRequestContext: SmokeInwardsRequestContext,
                                         invocationContext: InvocationContext, status: HTTPResponseStatus) {
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
        
        var logMetadata: Logger.Metadata = [
            "requestLatencyMS": "\(requestLatency)",
            "serviceCallCount":"\(serviceCallCount)",
            "serviceCallLatencyMS": "\(serviceCallLatency)",
            "retryServiceCallCount": "\(retriedServiceCalls.count)",
            "retryWaitLatencyMS": "\(retryWaitLatency)"]
        
        if let headReceiveDate = smokeInwardsRequestContext.headReceiveDate {
            let requestReadLatency = smokeInwardsRequestContext.requestStart.timeIntervalSince(headReceiveDate).milliseconds
            logMetadata["requestReadLatencyMS"] = "\(requestReadLatency)"
            
            invocationContext.requestReadLatencyTimer?.recordMilliseconds(requestReadLatency)
        }
        
        invocationContext.logger.info("Inwards request complete.", metadata: logMetadata)
        
        invocationContext.latencyTimer?.recordMilliseconds(requestLatency)
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
    
    private func handleComplete(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                responseComponents: HTTP1ServerResponseComponents, reportRequest: Bool) {
        var headers = HTTPHeaders()
        
        let data: Data?
        let bodySize: Int
        
        // if there is a body
        if let body = responseComponents.body {
            data = body.data
            bodySize = body.data.count
            
            // add the content type header
            headers.add(name: HTTP1Headers.contentType, value: body.contentType)
        } else {
            data = nil
            bodySize = 0
        }
        
        // add the content length header and write the response head to the response
        headers.add(name: HTTP1Headers.contentLength, value: "\(bodySize)")
        
        // add any additional headers
        responseComponents.additionalHeaders.forEach { header in
            headers.add(name: header.0, value: header.1)
        }
        
        if reportRequest {
            invocationContext.handleInwardsRequestComplete(httpHeaders: &headers, status: status, body: responseComponents.body)
        }
        
        if let smokeInwardsRequestContext = self.smokeInwardsRequestContext, reportRequest {
            reportRequestOnComplete(smokeInwardsRequestContext: smokeInwardsRequestContext,
                                    invocationContext: invocationContext, status: status)
        }
        
        let responseHead = HTTPResponseHead(version: requestHead.version,
                                            status: status,
                                            headers: headers)
        
        let responseBody: HBResponseBody
        // if there is a body, write it to the response
        if let data = data {
            let body = ByteBuffer(data: data)
            
            responseBody = .byteBuffer(body)
        } else {
            responseBody = .empty
        }
        
        let response = HBHTTPResponse(head: responseHead, body: responseBody)
        onComplete(.success(response))
    }
}

private extension TimeInterval {
    var milliseconds: Int {
        return Int(self * timeIntervalToMilliseconds)
    }
}
