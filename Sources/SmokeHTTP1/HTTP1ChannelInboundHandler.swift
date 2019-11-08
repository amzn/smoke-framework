// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// HTTP1ChannelInboundHandler.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat
import SmokeOperations
import Logging

private protocol CommonStatePayload {
    var logger: Logger { get }
    var internalRequestId: String { get }
    var requestHead: HTTPRequestHead { get }
    var keepAliveStatus: KeepAliveStatus { get }
}

/**
 Handler that manages the inbound channel for a HTTP Request.
 */
class HTTP1ChannelInboundHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private struct WaitingForRequestBody: CommonStatePayload {
        let logger: Logger
        let internalRequestId: String
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        
        init(requestHead: HTTPRequestHead) {
            self.internalRequestId = UUID().uuidString
            var newLogger = Logger(label: "com.amazon.SmokeFramework.request.\(internalRequestId)")
            newLogger[metadataKey: "internalRequestId"] = "\(internalRequestId)"
            
            self.logger = newLogger
            self.requestHead = requestHead
            self.keepAliveStatus = KeepAliveStatus(state: requestHead.isKeepAlive)
        }
    }
    
    private struct ReceivingRequestBody: CommonStatePayload {
        let logger: Logger
        let internalRequestId: String
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        let partialBody: Data
        
        init(waitingForRequestBody: WaitingForRequestBody, bodyPart: Data) {
            self.logger = waitingForRequestBody.logger
            self.internalRequestId = waitingForRequestBody.internalRequestId
            self.requestHead = waitingForRequestBody.requestHead
            self.keepAliveStatus = waitingForRequestBody.keepAliveStatus
            self.partialBody = bodyPart
        }
        
        init(receivingRequestBody: ReceivingRequestBody, bodyPart: Data) {
            self.logger = receivingRequestBody.logger
            self.internalRequestId = receivingRequestBody.internalRequestId
            self.requestHead = receivingRequestBody.requestHead
            self.keepAliveStatus = receivingRequestBody.keepAliveStatus
            
            var newPartialBody = receivingRequestBody.partialBody
            newPartialBody += bodyPart
            self.partialBody = newPartialBody
        }
    }
    
    private struct PendingResponse: CommonStatePayload {
        let logger: Logger
        let internalRequestId: String
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        let bodyData: Data?
        
        init(waitingForRequestBody: WaitingForRequestBody) {
            self.logger = waitingForRequestBody.logger
            self.internalRequestId = waitingForRequestBody.internalRequestId
            self.requestHead = waitingForRequestBody.requestHead
            self.keepAliveStatus = waitingForRequestBody.keepAliveStatus
            self.bodyData = nil
        }
        
        init(receivingRequestBody: ReceivingRequestBody) {
            self.logger = receivingRequestBody.logger
            self.internalRequestId = receivingRequestBody.internalRequestId
            self.requestHead = receivingRequestBody.requestHead
            self.keepAliveStatus = receivingRequestBody.keepAliveStatus
            self.bodyData = receivingRequestBody.partialBody
        }
        
        init(pendingResponse: PendingResponse, keepAliveStatus: Bool) {
            self.internalRequestId = pendingResponse.internalRequestId
            self.logger = pendingResponse.logger
            self.requestHead = pendingResponse.requestHead
            self.keepAliveStatus = pendingResponse.keepAliveStatus
            self.bodyData = pendingResponse.bodyData
            
            self.keepAliveStatus.state = keepAliveStatus
        }
    }
    
    /**
     Internal state variable that tracks the progress
     of the HTTP Request and Response.
     */
    private enum State {
        case idle
        case waitingForRequestBody(WaitingForRequestBody)
        case receivingRequestBody(ReceivingRequestBody)
        case pendingResponse(PendingResponse)

        mutating func requestReceived(requestHead: HTTPRequestHead) -> WaitingForRequestBody {
            switch self {
            case .idle:
                let statePayload = WaitingForRequestBody(requestHead: requestHead)
                self = .waitingForRequestBody(statePayload)
                
                return statePayload
            case .waitingForRequestBody, .receivingRequestBody, .pendingResponse:
                assertionFailure("Invalid state for request received: \(self)")
                
                fatalError()
            }
        }
        
        mutating func partialBodyReceived(bodyPart: Data?) -> CommonStatePayload {
            switch self {
            case .waitingForRequestBody(let waitingForRequestBody):
                if let bodyPart = bodyPart {
                    let statePayload = ReceivingRequestBody(waitingForRequestBody: waitingForRequestBody, bodyPart: bodyPart)
                    self = .receivingRequestBody(statePayload)
                    
                    return statePayload
                } else {
                    // no additional body, no actual state change
                    return waitingForRequestBody
                }
            case .receivingRequestBody(let receivingRequestBody):
                if let bodyPart = bodyPart {
                    let statePayload = ReceivingRequestBody(receivingRequestBody: receivingRequestBody, bodyPart: bodyPart)
                    self = .receivingRequestBody(statePayload)
                    
                    return statePayload
                } else {
                    // no additional body, no actual state change
                    return receivingRequestBody
                }
            case .idle, .pendingResponse:
                assertionFailure("Invalid state for partial body received: \(self)")
                    
                fatalError()
            }
        }

        mutating func requestComplete() -> PendingResponse {
            switch self {
            case .waitingForRequestBody(let waitingForRequestBody):
                self = .idle
                
                return PendingResponse(waitingForRequestBody: waitingForRequestBody)
            case .receivingRequestBody(let receivingRequestBody):
                self = .idle
                
                return PendingResponse(receivingRequestBody: receivingRequestBody)
            case .idle, .pendingResponse:
                assertionFailure("Invalid state for request complete: \(self)")
                
                fatalError()
            }
        }
        
        mutating func updateKeepAliveStatus(keepAliveStatus: Bool) -> Bool {
            switch self {
            case .waitingForRequestBody:
                return true
            case .receivingRequestBody:
                return true
            case .pendingResponse(let pendingResponse):
                self = .pendingResponse(PendingResponse(pendingResponse: pendingResponse, keepAliveStatus: keepAliveStatus))
                
                return false
            case .idle:
                assertionFailure("Invalid state to update keep alive status: \(self)")
                
                fatalError()
            }
        }
    }
    
    private let handler: HTTP1RequestHandler
    private let invocationStrategy: InvocationStrategy
    
    private var state = State.idle
    
    init(handler: HTTP1RequestHandler,
         invocationStrategy: InvocationStrategy) {
        self.handler = handler
        self.invocationStrategy = invocationStrategy
    }
    
    /**
     Function called when the inbound channel receives data.
     */
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let requestHead):
            let statePayload = self.state.requestReceived(requestHead: requestHead)

            statePayload.logger.debug("Request head received.")
        case .body(var byteBuffer):
            let byteBufferSize = byteBuffer.readableBytes
            let newData = byteBuffer.readData(length: byteBufferSize)
            
            let statePayload = self.state.partialBodyReceived(bodyPart: newData)

            statePayload.logger.debug("Request body part of \(byteBufferSize) bytes received.")
        case .end:
            // this signals that the head and all possible body parts have been received
            let pendingResponse = self.state.requestComplete()
            
            pendingResponse.logger.debug("Request end received.")

            handleCompleteRequest(context: context, pendingResponse: pendingResponse)
        }
    }
    
    /**
     Is called when the request has been completed received
     and can be passed to the request hander.
     */
    private func handleCompleteRequest(context: ChannelHandlerContext, pendingResponse: PendingResponse) {
        let logger = pendingResponse.logger
        let bodyData = pendingResponse.bodyData
        let requestHead = pendingResponse.requestHead
        
        logger.debug("Handling request body with \(bodyData?.count ?? 0) size.")
        
        // create a response handler for this request
        let responseHandler = StandardHTTP1ResponseHandler(
            requestHead: requestHead,
            keepAliveStatus: pendingResponse.keepAliveStatus,
            context: context,
            wrapOutboundOut: wrapOutboundOut)
    
        let currentHandler = handler
        
        // pass to the request handler to complete
        currentHandler.handle(requestHead: requestHead,
                              body: bodyData,
                              responseHandler: responseHandler,
                              invocationStrategy: invocationStrategy)
    }
    
    /**
     Called when reading from the channel is completed.
     */
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    /**
     Writes a error to the response and closes the channel.
     */
    func handleResponseAsError(context: ChannelHandlerContext,
                               responseString: String,
                               status: HTTPResponseStatus) {
        var headers = HTTPHeaders()
        var buffer = context.channel.allocator.buffer(capacity: responseString.utf8.count)
        buffer.setString(responseString, at: 0)
        
        headers.add(name: HTTP1Headers.contentLength, value: "\(responseString.utf8.count)")
        context.write(self.wrapOutboundOut(.head(HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1),
                                                                  status: status,
                                                                  headers: headers))), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)),
                              promise: nil)
        context.close(promise: nil)
    }
    
    /**
     Called when an inbound event occurs.
     */
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        // if the remote peer half-closed the channel.
        case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
            if self.state.updateKeepAliveStatus(keepAliveStatus: false) {
                // not waiting on anything else, channel can be closed
                // immediately
                context.close(promise: nil)
            }
        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
}
