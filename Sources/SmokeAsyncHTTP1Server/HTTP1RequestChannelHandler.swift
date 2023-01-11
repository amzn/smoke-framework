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

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat
import Logging

internal struct HTTP1Headers {
    /// Content-Length Header
    static let contentLength = "Content-Length"

    /// Content-Type Header
    static let contentType = "Content-Type"
}

/**
 Handler that manages the inbound channel for a HTTP Request.
 */
class HTTP1RequestChannelHandler<ResponseBodyType: AsyncSequence>: ChannelInboundHandler
where ResponseBodyType.Element == Data {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private struct WaitingForRequestBody {
        let request: SmokeHTTP1Request
        let bodyPartHander: (Data) -> ()
        let bodyPartStreamFinishHandler: () -> ()
        
        init(requestHead: HTTPRequestHead) {
            var newBodyPartHander: ((Data) -> ())?
            var newBodyPartStreamFinishHandler: (() -> ())?
            // create an async stream with a handler for adding new body parts
            // and a handler for finishing the stream
            let bodyPartStream = AsyncStream { continuation in
                newBodyPartHander = { entry in
                    continuation.yield(entry)
                }
                
                newBodyPartStreamFinishHandler = {
                    continuation.finish()
                }
            }
            
            guard let newBodyPartHander = newBodyPartHander, let newBodyPartStreamFinishHandler = newBodyPartStreamFinishHandler else {
                fatalError()
            }
            
            
            self.request = SmokeHTTP1Request(head: requestHead, bodyStream: bodyPartStream)
            
            self.bodyPartHander = newBodyPartHander
            self.bodyPartStreamFinishHandler = newBodyPartStreamFinishHandler
        }
    }
    
    private struct ReceivingRequestBody {
        let request: SmokeHTTP1Request
        let bodyPartHander: (Data) -> ()
        let bodyPartStreamFinishHandler: () -> ()
        
        init(waitingForRequestBody: WaitingForRequestBody, bodyPart: Data) {
            self.request = waitingForRequestBody.request
            
            self.bodyPartHander = waitingForRequestBody.bodyPartHander
            self.bodyPartStreamFinishHandler = waitingForRequestBody.bodyPartStreamFinishHandler
            
            self.bodyPartHander(bodyPart)
        }
        
        init(receivingRequestBody: ReceivingRequestBody, bodyPart: Data) {
            self.request = receivingRequestBody.request
            
            self.bodyPartHander = receivingRequestBody.bodyPartHander
            self.bodyPartStreamFinishHandler = receivingRequestBody.bodyPartStreamFinishHandler
            
            self.bodyPartHander(bodyPart)
        }
    }
    
    private struct PendingResponseHead {
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        let context: ChannelHandlerContext
        let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
        
        init(requestHead: HTTPRequestHead,
             context: ChannelHandlerContext,
             wrapOutboundOut: @escaping (_ value: HTTPServerResponsePart) -> NIOAny) {
            self.requestHead = requestHead
            self.context = context
            self.wrapOutboundOut = wrapOutboundOut
            self.keepAliveStatus = KeepAliveStatus(state: requestHead.isKeepAlive)
        }
        
        init(pendingResponseHead: PendingResponseHead, keepAliveStatus: Bool) {
            self.requestHead = pendingResponseHead.requestHead
            self.context = pendingResponseHead.context
            self.wrapOutboundOut = pendingResponseHead.wrapOutboundOut
            self.keepAliveStatus = pendingResponseHead.keepAliveStatus
            
            self.keepAliveStatus.state = keepAliveStatus
        }
    }
    
    private struct PendingResponseBody {
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        let context: ChannelHandlerContext
        let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
        
        init(pendingResponseHead: PendingResponseHead) {
            self.requestHead = pendingResponseHead.requestHead
            self.keepAliveStatus = pendingResponseHead.keepAliveStatus
            self.context = pendingResponseHead.context
            self.wrapOutboundOut = pendingResponseHead.wrapOutboundOut
        }
        
        init(sendingResponseBody: SendingResponseBody) {
            self.requestHead = sendingResponseBody.requestHead
            self.keepAliveStatus = sendingResponseBody.keepAliveStatus
            self.context = sendingResponseBody.context
            self.wrapOutboundOut = sendingResponseBody.wrapOutboundOut
        }
        
        init(pendingResponseBody: PendingResponseBody, keepAliveStatus: Bool) {
            self.requestHead = pendingResponseBody.requestHead
            self.keepAliveStatus = pendingResponseBody.keepAliveStatus
            self.context = pendingResponseBody.context
            self.wrapOutboundOut = pendingResponseBody.wrapOutboundOut
            
            self.keepAliveStatus.state = keepAliveStatus
        }
    }
    
    private struct SendingResponseBody {
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        let context: ChannelHandlerContext
        let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
        
        init(pendingResponseBody: PendingResponseBody) {
            self.requestHead = pendingResponseBody.requestHead
            self.keepAliveStatus = pendingResponseBody.keepAliveStatus
            self.context = pendingResponseBody.context
            self.wrapOutboundOut = pendingResponseBody.wrapOutboundOut
        }
        
        init(sendingResponseBody: SendingResponseBody) {
            self.requestHead = sendingResponseBody.requestHead
            self.keepAliveStatus = sendingResponseBody.keepAliveStatus
            self.context = sendingResponseBody.context
            self.wrapOutboundOut = sendingResponseBody.wrapOutboundOut
        }
        
        init(sendingResponseBody: SendingResponseBody, keepAliveStatus: Bool) {
            self.requestHead = sendingResponseBody.requestHead
            self.keepAliveStatus = sendingResponseBody.keepAliveStatus
            self.context = sendingResponseBody.context
            self.wrapOutboundOut = sendingResponseBody.wrapOutboundOut
            
            self.keepAliveStatus.state = keepAliveStatus
        }
    }
    
    /**
     Internal state variable that tracks the progress of the HTTP Request.
     */
    private enum RequestState {
        case idle
        case waitingForRequestBody(WaitingForRequestBody)
        case receivingRequestBody(ReceivingRequestBody)

        mutating func requestReceived(requestHead: HTTPRequestHead) -> WaitingForRequestBody {
            switch self {
            case .idle:
                let statePayload = WaitingForRequestBody(requestHead: requestHead)
                self = .waitingForRequestBody(statePayload)
                
                return statePayload
            case .waitingForRequestBody, .receivingRequestBody:
                assertionFailure("Invalid state for request received: \(self)")
                
                fatalError()
            }
        }
        
        mutating func partialBodyReceived(bodyPart: Data?) {
            switch self {
            case .waitingForRequestBody(let waitingForRequestBody):
                if let bodyPart = bodyPart {
                    let statePayload = ReceivingRequestBody(waitingForRequestBody: waitingForRequestBody, bodyPart: bodyPart)
                    self = .receivingRequestBody(statePayload)
                }
            case .receivingRequestBody(let receivingRequestBody):
                if let bodyPart = bodyPart {
                    let statePayload = ReceivingRequestBody(receivingRequestBody: receivingRequestBody, bodyPart: bodyPart)
                    self = .receivingRequestBody(statePayload)
                }
            case .idle:
                assertionFailure("Invalid state for partial body received: \(self)")
                    
                fatalError()
            }
        }

        mutating func requestFullyReceived() {
            switch self {
            case .waitingForRequestBody, .receivingRequestBody:
                self = .idle
            case .idle:
                assertionFailure("Invalid state for request complete: \(self)")
                
                fatalError()
            }
        }
    }
    
    /**
     Internal state variable that tracks the progress of the HTTP Response.
     */
    private enum ResponseState {
        case idle
        case pendingResponseHead(PendingResponseHead)
        case pendingResponseBody(PendingResponseBody)
        case sendingResponseBody(SendingResponseBody)
        
        mutating func waitForResponse(requestHead: HTTPRequestHead,
                                      context: ChannelHandlerContext,
                                      wrapOutboundOut: @escaping (_ value: HTTPServerResponsePart) -> NIOAny) {
            switch self {
            case .idle:
                let pendingResponseHead = PendingResponseHead(requestHead: requestHead, context: context, wrapOutboundOut: wrapOutboundOut)
                self = .pendingResponseHead(pendingResponseHead)
            case .pendingResponseHead, .pendingResponseBody, .sendingResponseBody:
                assertionFailure("Invalid state for requestReceived: \(self)")
                
                fatalError()
            }
        }
        
        mutating func sendResponseHead(response: SmokeHTTP1Response<ResponseBodyType>) {
            switch self {
            case .pendingResponseHead(let pendingResponseHead):
                var headers = HTTPHeaders()
                
                // if there is a content type
                if let body = response.body {
                    // add the content type header
                    headers.add(name: HTTP1Headers.contentType, value: body.contentType)
                
                    // add the content length header and write the response head to the response
                    if let bodySize = body.size {
                        headers.add(name: HTTP1Headers.contentLength, value: "\(bodySize)")
                    }
                }
                
                // add any additional headers
                response.additionalHeaders.forEach { header in
                    headers.add(name: header.0, value: header.1)
                }
                
                let context = pendingResponseHead.context
                let requestHead = pendingResponseHead.requestHead
                let wrapOutboundOut = pendingResponseHead.wrapOutboundOut
                
                context.write(wrapOutboundOut(.head(HTTPResponseHead(version: requestHead.version,
                                                                     status: response.status,
                                                                     headers: headers))), promise: nil)
                
                self = .pendingResponseBody(PendingResponseBody(pendingResponseHead: pendingResponseHead))
            case .idle, .pendingResponseBody, .sendingResponseBody:
                assertionFailure("Invalid state for responseFullySent: \(self)")
                
                fatalError()
            }
        }
        
        mutating func sendResponseBodyPart(bodyPart: Data) {
            let context: ChannelHandlerContext
            let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
            switch self {
            case .pendingResponseBody(let pendingResponseBody):
                context = pendingResponseBody.context
                wrapOutboundOut = pendingResponseBody.wrapOutboundOut
                
                let sendingResponseBody = SendingResponseBody(pendingResponseBody: pendingResponseBody)
                self = .sendingResponseBody(sendingResponseBody)
            case .sendingResponseBody(let sendingResponseBody):
                context = sendingResponseBody.context
                wrapOutboundOut = sendingResponseBody.wrapOutboundOut
                
                let sendingResponseBody = SendingResponseBody(sendingResponseBody: sendingResponseBody)
                self = .sendingResponseBody(sendingResponseBody)
            case .idle, .pendingResponseHead:
                assertionFailure("Invalid state for sendResponseBodyPart: \(self)")
                
                fatalError()
            }
            
            // create a buffer for the body and copy the body into it
            var buffer = context.channel.allocator.buffer(capacity: bodyPart.count)
            buffer.writeBytes(bodyPart)
            
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }
        
        mutating func responseFullySent() {
            let keepAliveStatus: KeepAliveStatus
            let context: ChannelHandlerContext
            let wrapOutboundOut: (_ value: HTTPServerResponsePart) -> NIOAny
            switch self {
            case .pendingResponseBody(let pendingResponseBody):
                keepAliveStatus = pendingResponseBody.keepAliveStatus
                context = pendingResponseBody.context
                wrapOutboundOut = pendingResponseBody.wrapOutboundOut
            case .sendingResponseBody(let sendingResponseBody):
                keepAliveStatus = sendingResponseBody.keepAliveStatus
                context = sendingResponseBody.context
                wrapOutboundOut = sendingResponseBody.wrapOutboundOut
            case .idle, .pendingResponseHead:
                assertionFailure("Invalid state for responseFullySent: \(self)")
                
                fatalError()
            }
            
            let promise: EventLoopPromise<Void>? = keepAliveStatus.state ? nil : context.eventLoop.makePromise()
            if let promise = promise {
                // if keep alive is false, close the channel when the response end
                // has been written
                promise.futureResult.whenComplete { _ in
                    context.close(promise: nil)
                }
            }
            
            // write the response end and flush
            context.writeAndFlush(wrapOutboundOut(HTTPServerResponsePart.end(nil)),
                              promise: promise)
            
            self = .idle
        }
        
        mutating func updateKeepAliveStatus(keepAliveStatus: Bool) -> Bool {
            switch self {
            case .idle:
                return true
            case .pendingResponseHead(let pendingResponseHead):
                self = .pendingResponseHead(PendingResponseHead(pendingResponseHead: pendingResponseHead, keepAliveStatus: keepAliveStatus))
                
                return false
            case .pendingResponseBody(let pendingResponseBody):
                self = .pendingResponseBody(PendingResponseBody(pendingResponseBody: pendingResponseBody, keepAliveStatus: keepAliveStatus))
                
                return false
            case .sendingResponseBody(let sendingResponseBody):
                self = .sendingResponseBody(SendingResponseBody(sendingResponseBody: sendingResponseBody, keepAliveStatus: keepAliveStatus))
                
                return false
            }
        }
    }
    
    private let handler: (SmokeHTTP1Request) async -> SmokeHTTP1Response<ResponseBodyType>
    
    private var requestState = RequestState.idle
    private var responseState = ResponseState.idle
    private let channelLogger: Logger
    
    init(handler: @escaping (SmokeHTTP1Request) async -> SmokeHTTP1Response<ResponseBodyType>) {
        self.handler = handler
        
        var newChannelLogger = Logger(label: "HTTP1RequestChannelHandler")
        newChannelLogger[metadataKey: "lifecycle"] = "HTTP1RequestChannelHandler"
        
        self.channelLogger = newChannelLogger
    }
    
    /**
     Function called when the inbound channel receives data.
     */
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = self.unwrapInboundIn(data)
        
        switch requestPart {
        case .head(let requestHead):
            let waitingForRequestBody = self.requestState.requestReceived(requestHead: requestHead)
            self.responseState.waitForResponse(requestHead: requestHead, context: context, wrapOutboundOut: wrapOutboundOut)
            
            handleNewRequest(context: context, waitingForRequestBody: waitingForRequestBody)
        case .body(var byteBuffer):
            let byteBufferSize = byteBuffer.readableBytes
            let newData = byteBuffer.readData(length: byteBufferSize)
            
            self.requestState.partialBodyReceived(bodyPart: newData)
        case .end:
            // this signals that the head and all possible body parts have been received
            self.requestState.requestFullyReceived()
        }
    }
    
    private func handleNewRequest(context: ChannelHandlerContext, waitingForRequestBody: WaitingForRequestBody) {
        let eventLoop = context.eventLoop
        
        // TODO: use a disgarding thread group
        Task {
            let response = await self.handler(waitingForRequestBody.request)
            
            eventLoop.execute {
                self.responseState.sendResponseHead(response: response)
            }
            
            // await the body
            if let responseBody = response.body {
                do {
                    for try await bodyPart in responseBody.stream {
                        eventLoop.execute {
                            self.responseState.sendResponseBodyPart(bodyPart: bodyPart)
                        }
                    }
                } catch {
                    self.channelLogger.error(
                        "Error caught while sending body: \(String(describing: error)). Body may not be completely sent.")
                }
            }
            
            eventLoop.execute {
                self.responseState.responseFullySent()
            }
        }
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
            if self.responseState.updateKeepAliveStatus(keepAliveStatus: false) {
                // not waiting on anything else, channel can be closed
                // immediately
                context.close(promise: nil)
            }
        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.channelLogger.warning(
            "Closing ChannelHandlerContext from state '\(self)' due to error received: \(String(describing: error))")
        
        context.close(promise: nil)
        
        self.requestState = .idle
        self.responseState = .idle
    }
}
