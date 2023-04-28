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
// AsyncHTTP1ChannelManager.swift
// SmokeAsyncHTTP1Server
//

import Foundation
@_spi(AsyncChannel) import NIOCore
import NIOHTTP1
import Logging
import AsyncAlgorithms

internal struct HTTP1Headers {
    /// Content-Length Header
    static let contentLength = "Content-Length"

    /// Content-Type Header
    static let contentType = "Content-Type"
}

/**
 Actor that manages the state of a HTTP1 channel.
 */
actor AsyncHTTP1ChannelManager {
    
    private struct WaitingForRequestBody {
        let request: HTTPServerRequest
        let bodyChannel: AsyncThrowingChannel<ByteBuffer, Error>
        
        init(requestHead: HTTPRequestHead) {
            let bodyChannel: AsyncThrowingChannel<ByteBuffer, Error> = .init()
            
            self.request = HTTPServerRequest(method: requestHead.method,
                                             version: requestHead.version,
                                             uri: requestHead.uri,
                                             headers: requestHead.headers,
                                             body: .stream(bodyChannel))
                        
            self.bodyChannel = bodyChannel
        }
    }
    
    private struct ReceivingRequestBody {
        let request: HTTPServerRequest
        let bodyChannel: AsyncThrowingChannel<ByteBuffer, Error>
        
        init(waitingForRequestBody: WaitingForRequestBody) {
            self.request = waitingForRequestBody.request
            
            self.bodyChannel = waitingForRequestBody.bodyChannel
        }
        
        init(receivingRequestBody: ReceivingRequestBody) {
            self.request = receivingRequestBody.request
            
            self.bodyChannel = receivingRequestBody.bodyChannel
        }
    }
    
    private struct PendingResponseHead {
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        
        init(requestHead: HTTPRequestHead) {
            self.requestHead = requestHead
            self.keepAliveStatus = KeepAliveStatus(state: requestHead.isKeepAlive)
        }
        
        init(pendingResponseHead: PendingResponseHead, keepAliveStatus: Bool) {
            self.requestHead = pendingResponseHead.requestHead
            self.keepAliveStatus = pendingResponseHead.keepAliveStatus
            
            self.keepAliveStatus.state = keepAliveStatus
        }
    }
    
    private struct PendingResponseBody {
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        
        init(pendingResponseHead: PendingResponseHead) {
            self.requestHead = pendingResponseHead.requestHead
            self.keepAliveStatus = pendingResponseHead.keepAliveStatus
        }
        
        init(sendingResponseBody: SendingResponseBody) {
            self.requestHead = sendingResponseBody.requestHead
            self.keepAliveStatus = sendingResponseBody.keepAliveStatus
        }
        
        init(pendingResponseBody: PendingResponseBody, keepAliveStatus: Bool) {
            self.requestHead = pendingResponseBody.requestHead
            self.keepAliveStatus = pendingResponseBody.keepAliveStatus
            
            self.keepAliveStatus.state = keepAliveStatus
        }
    }
    
    private struct SendingResponseBody {
        let requestHead: HTTPRequestHead
        let keepAliveStatus: KeepAliveStatus
        
        init(pendingResponseBody: PendingResponseBody) {
            self.requestHead = pendingResponseBody.requestHead
            self.keepAliveStatus = pendingResponseBody.keepAliveStatus
        }
        
        init(sendingResponseBody: SendingResponseBody) {
            self.requestHead = sendingResponseBody.requestHead
            self.keepAliveStatus = sendingResponseBody.keepAliveStatus
        }
        
        init(sendingResponseBody: SendingResponseBody, keepAliveStatus: Bool) {
            self.requestHead = sendingResponseBody.requestHead
            self.keepAliveStatus = sendingResponseBody.keepAliveStatus
            
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
        case waitingForResponseComplete
        case incomingStreamReset

        mutating func requestReceived(requestHead: HTTPRequestHead) -> HTTPServerRequest {
            switch self {
            case .idle:
                let statePayload = WaitingForRequestBody(requestHead: requestHead)
                self = .waitingForRequestBody(statePayload)
                
                return statePayload.request
            case .waitingForRequestBody, .receivingRequestBody, .waitingForResponseComplete, .incomingStreamReset:
                assertionFailure("Invalid state for request received: \(self)")
                
                fatalError()
            }
        }
        
        mutating func partialBodyReceived() -> AsyncThrowingChannel<ByteBuffer, Error>? {
            switch self {
            case .waitingForRequestBody(let waitingForRequestBody):
                let statePayload = ReceivingRequestBody(waitingForRequestBody: waitingForRequestBody)
                self = .receivingRequestBody(statePayload)
                
                return statePayload.bodyChannel
            case .receivingRequestBody(let receivingRequestBody):
                let statePayload = ReceivingRequestBody(receivingRequestBody: receivingRequestBody)
                self = .receivingRequestBody(statePayload)
                
                return statePayload.bodyChannel
            case .incomingStreamReset:
                return nil
            case .idle, .waitingForResponseComplete:
                assertionFailure("Invalid state for partial body received: \(self)")
                    
                fatalError()
            }
        }

        mutating func requestFullyReceived(responseState: inout ResponseState) {
            let bodyChannel: AsyncThrowingChannel<ByteBuffer, Error>?
            
            let nextState: RequestState
            switch responseState {
            case .idle, .pendingResponseHead, .pendingResponseBody, .sendingResponseBody:
                nextState = .waitingForResponseComplete
            case .waitingForRequestComplete:
                nextState = .idle
                responseState = .idle
            }
            
            switch self {
            case .waitingForRequestBody(let state):
                bodyChannel = state.bodyChannel
            case .receivingRequestBody(let state):
                bodyChannel = state.bodyChannel
            case .incomingStreamReset:
                bodyChannel = nil
            case .idle, .waitingForResponseComplete:
                assertionFailure("Invalid state for request complete: \(self)")
                
                fatalError()
            }
            
            self = nextState
            
            // signal that the body part stream has completed
            bodyChannel?.finish()
        }
        
        mutating func confirmFinished() {
            switch self {
            case .waitingForResponseComplete, .incomingStreamReset:
                // nothing to do
                return
            case .waitingForRequestBody(let state):
                state.bodyChannel.finish()
            case .receivingRequestBody(let state):
                state.bodyChannel.finish()
            case .idle:
                assertionFailure("Invalid state for reset: \(self)")
                
                fatalError()
            }
            
            self = .incomingStreamReset
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
        case waitingForRequestComplete
        
        mutating func waitForResponse(requestHead: HTTPRequestHead) {
            switch self {
            case .idle:
                let pendingResponseHead = PendingResponseHead(requestHead: requestHead)
                self = .pendingResponseHead(pendingResponseHead)
            case .pendingResponseHead, .pendingResponseBody, .sendingResponseBody, .waitingForRequestComplete:
                assertionFailure("Invalid state for requestReceived: \(self)")
                
                fatalError()
            }
        }
        
        mutating func sendResponseHead(response: HTTPServerResponse) -> HTTPResponseHead {
            switch self {
            case .pendingResponseHead(let pendingResponseHead):
                var headers = response.headers
                
                // if there is a content type
                if let body = response.body {
                    // add the content type header
                    headers.add(name: HTTP1Headers.contentType, value: body.contentType)
                
                    // add the content length header and write the response head to the response
                    if let bodySize = body.size {
                        headers.add(name: HTTP1Headers.contentLength, value: "\(bodySize)")
                    }
                }
                
                let requestHead = pendingResponseHead.requestHead
                
                let head = HTTPResponseHead(version: requestHead.version,
                                            status: response.status,
                                            headers: headers)
                
                self = .pendingResponseBody(PendingResponseBody(pendingResponseHead: pendingResponseHead))
                
                return head
            case .idle, .pendingResponseBody, .sendingResponseBody, .waitingForRequestComplete:
                assertionFailure("Invalid state for responseFullySent: \(self)")
                
                fatalError()
            }
        }
        
        mutating func sendResponseBodyPart() {
            switch self {
            case .pendingResponseBody(let pendingResponseBody):
                let sendingResponseBody = SendingResponseBody(pendingResponseBody: pendingResponseBody)
                self = .sendingResponseBody(sendingResponseBody)
            case .sendingResponseBody(let sendingResponseBody):
                let sendingResponseBody = SendingResponseBody(sendingResponseBody: sendingResponseBody)
                self = .sendingResponseBody(sendingResponseBody)
            case .idle, .pendingResponseHead, .waitingForRequestComplete:
                assertionFailure("Invalid state for sendResponseBodyPart: \(self)")
                
                fatalError()
            }
        }
        
        mutating func responseFullySent(requestState: inout RequestState) -> Bool {
            let keepAliveStatus: KeepAliveStatus
            switch self {
            case .pendingResponseBody(let pendingResponseBody):
                keepAliveStatus = pendingResponseBody.keepAliveStatus
            case .sendingResponseBody(let sendingResponseBody):
                keepAliveStatus = sendingResponseBody.keepAliveStatus
            case .idle, .pendingResponseHead, .waitingForRequestComplete:
                assertionFailure("Invalid state for responseFullySent: \(self)")
                
                fatalError()
            }
            
            switch requestState {
            case .idle, .waitingForRequestBody, .receivingRequestBody, .incomingStreamReset:
                self = .waitingForRequestComplete
            case .waitingForResponseComplete:
                self = .idle
                requestState = .idle
            }
            
            return keepAliveStatus.state
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
            case .waitingForRequestComplete:
                assertionFailure("Invalid state for updateKeepAliveStatus: \(self)")
                
                fatalError()
            }
        }
    }
    
    private let handler: @Sendable (HTTPServerRequest) async -> HTTPServerResponse
    private let requestChannel: AsyncThrowingChannel<HTTPServerRequest, Error>
    
    private var requestState = RequestState.idle
    private var responseState = ResponseState.idle
    private let channelLogger: Logger
    
    init(handler: @Sendable @escaping (HTTPServerRequest) async -> HTTPServerResponse) {
        self.handler = handler
        
        var newChannelLogger = Logger(label: "HTTP1RequestChannelHandler")
        newChannelLogger[metadataKey: "lifecycle"] = "HTTP1RequestChannelHandler"
        
        self.channelLogger = newChannelLogger
        self.requestChannel = .init()
    }
    
    private enum ChildTaskResult {
        case inboundConsumptionFinished
        case inboundConsumptionThrew
        case outboundSubmitFinished
        case outboundSubmitThrew
    }
    
    func process(asyncChannel: NIOAsyncChannel<HTTPServerRequestPart, AsyncHTTPServerResponsePart>) async {
        await withTaskGroup(of: ChildTaskResult.self, returning: Void.self) { group in
            group.addTask {
                do {
                    for try await request in self.requestChannel {
                        await self.handle(request: request, outboundWriter: asyncChannel.outboundWriter)
                    }
                    
                    return .outboundSubmitFinished
                } catch {
                    return .outboundSubmitThrew
                }
            }
            
            group.addTask {
                do {
                    for try await part in asyncChannel.inboundStream {
                        await self.process(requestPart: part)
                    }
                    
                    return .inboundConsumptionFinished
                } catch {
                    return .inboundConsumptionThrew
                }
            }
            
            resultIteration: for await result in group {
                switch result {
                case .inboundConsumptionFinished:
                    // this is valid case to finish early and can be ignored
                    continue
                case .outboundSubmitFinished:
                    // everything is done
                    break resultIteration
                case .outboundSubmitThrew:
                    // TODO: Handle the error
                    break resultIteration
                case .inboundConsumptionThrew:
                    // TODO: Handle the error
                    break resultIteration
                }
            }
            
            // make sure everything from the channel is cancelled
            group.cancelAll()
        }
    }
    
    private func process(requestPart: HTTPServerRequestPart) async {
        switch requestPart {
        case .head(let requestHead):
            let request = self.requestState.requestReceived(requestHead: requestHead)
            self.responseState.waitForResponse(requestHead: requestHead)
            
            await self.requestChannel.send(request)
        case .body(let byteBuffer):
            let bodyChannel = self.requestState.partialBodyReceived()
            await bodyChannel?.send(byteBuffer)
        case .end:
            // this signals that the head and all possible body parts have been received
            self.requestState.requestFullyReceived(responseState: &self.responseState)
        }
    }
    
    private func handle(request: HTTPServerRequest,
                        outboundWriter: NIOAsyncChannelOutboundWriter<AsyncHTTPServerResponsePart>) async {
        let response = await self.handler(request)
        
        self.requestState.confirmFinished()
        
        func sendResponseBodyPart(bodyPart: ByteBuffer) async throws {
            self.responseState.sendResponseBodyPart()
            try await outboundWriter.write(.body(bodyPart))
        }
        
        do {
            // write the head
            let head = self.responseState.sendResponseHead(response: response)
            try await outboundWriter.write(.head(head))
            
            // await the body
            if let responseBody = response.body {
                switch responseBody.mode {
                case .byteBuffer(let buffer, _):
                    try await sendResponseBodyPart(bodyPart: buffer)
                case .asyncSequence(_, _, let makeAsyncIterator):
                    let allocator: ByteBufferAllocator = .init()
                    let next = makeAsyncIterator()
                    
                    while let part = try await next(allocator) {
                        try await sendResponseBodyPart(bodyPart: part)
                    }
                case .sequence(_, _, let makeCompleteBody):
                    let allocator: ByteBufferAllocator = .init()
                    let buffer = makeCompleteBody(allocator)
                    try await sendResponseBodyPart(bodyPart: buffer)
                }
            }
            
            try await outboundWriter.write(.end(nil))
            let keepAlive = self.responseState.responseFullySent(requestState: &self.requestState)
            
            if !keepAlive {
                outboundWriter.finish()
                self.requestChannel.finish()
            }
        } catch {
            self.channelLogger.error(
                "Error caught while sending body: \(String(describing: error)). Body may not be completely sent.")
        }
    }
}
