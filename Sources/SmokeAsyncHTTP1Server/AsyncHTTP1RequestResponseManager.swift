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
// AsyncHTTP1RequestResponseManager.swift
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
 Actor that manages the state of a request/response pair.
 */
actor AsyncHTTP1RequestResponseManager {
        
    private struct IdleRequest {
        var awaitingContinuations: [CheckedContinuation<HTTPServerRequest, Never>]
        
        init() {
            self.awaitingContinuations = []
        }
    }
    
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
    
    private struct IdleResponse {
        
        init() {
            
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
        case idle(IdleRequest)
        case waitingForRequestBody(WaitingForRequestBody)
        case receivingRequestBody(ReceivingRequestBody)
        case complete

        mutating func requestReceived(requestHead: HTTPRequestHead) -> WaitingForRequestBody {
            switch self {
            case .idle(let state):
                let statePayload = WaitingForRequestBody(requestHead: requestHead)
                self = .waitingForRequestBody(statePayload)
                
                state.awaitingContinuations.forEach { $0.resume(returning: statePayload.request) }
                
                return statePayload
            case .waitingForRequestBody, .receivingRequestBody, .complete:
                assertionFailure("Invalid state for request received: \(self)")
                
                fatalError()
            }
        }
        
        mutating func partialBodyReceived() -> AsyncThrowingChannel<ByteBuffer, Error> {
            switch self {
            case .waitingForRequestBody(let waitingForRequestBody):
                let statePayload = ReceivingRequestBody(waitingForRequestBody: waitingForRequestBody)
                self = .receivingRequestBody(statePayload)
                
                return statePayload.bodyChannel
            case .receivingRequestBody(let receivingRequestBody):
                let statePayload = ReceivingRequestBody(receivingRequestBody: receivingRequestBody)
                self = .receivingRequestBody(statePayload)
                
                return statePayload.bodyChannel
            case .idle, .complete:
                assertionFailure("Invalid state for partial body received: \(self)")
                    
                fatalError()
            }
        }

        mutating func requestFullyReceived() {
            let bodyChannel: AsyncThrowingChannel<ByteBuffer, Error>
            switch self {
            case .waitingForRequestBody(let state):
                self = .complete
                bodyChannel = state.bodyChannel
            case .receivingRequestBody(let state):
                self = .complete
                bodyChannel = state.bodyChannel
            case .idle, .complete:
                assertionFailure("Invalid state for request complete: \(self)")
                
                fatalError()
            }
            
            // signal that the body part stream has completed
            bodyChannel.finish()
        }
        
        mutating func continuationAwaitingRequestHead(_ awaitingContinuation: CheckedContinuation<HTTPServerRequest, Never>) {
            switch self {
            case .idle(var state):
                state.awaitingContinuations.append(awaitingContinuation)
                self = .idle(state)
            case .waitingForRequestBody(let state):
                awaitingContinuation.resume(returning: state.request)
            case .receivingRequestBody(let state):
                awaitingContinuation.resume(returning: state.request)
            case .complete:
                assertionFailure("Invalid state for continuationAwaitingRequestHead: \(self)")
                
                fatalError()
            }
        }
    }
    
    /**
     Internal state variable that tracks the progress of the HTTP Response.
     */
    private enum ResponseState {
        case idle(IdleResponse)
        case pendingResponseHead(PendingResponseHead)
        case pendingResponseBody(PendingResponseBody)
        case sendingResponseBody(SendingResponseBody)
        case complete
        
        mutating func waitForResponse(requestHead: HTTPRequestHead) {
            switch self {
            case .idle:
                let pendingResponseHead = PendingResponseHead(requestHead: requestHead)
                self = .pendingResponseHead(pendingResponseHead)
            case .pendingResponseHead, .pendingResponseBody, .sendingResponseBody, .complete:
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
            case .idle, .pendingResponseBody, .sendingResponseBody, .complete:
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
            case .idle, .pendingResponseHead, .complete:
                assertionFailure("Invalid state for sendResponseBodyPart: \(self)")
                
                fatalError()
            }
        }
        
        mutating func responseFullySent() -> Bool {
            let keepAliveStatus: KeepAliveStatus
            switch self {
            case .pendingResponseBody(let pendingResponseBody):
                keepAliveStatus = pendingResponseBody.keepAliveStatus
            case .sendingResponseBody(let sendingResponseBody):
                keepAliveStatus = sendingResponseBody.keepAliveStatus
            case .idle, .pendingResponseHead, .complete:
                assertionFailure("Invalid state for responseFullySent: \(self)")
                
                fatalError()
            }
            
            self = .complete
            
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
            case .complete:
                assertionFailure("Invalid state for updateKeepAliveStatus: \(self)")
                
                fatalError()
            }
        }
    }
    
    private let handler: @Sendable (HTTPServerRequest) async -> HTTPServerResponse
    
    private var requestState = RequestState.idle(.init())
    private var responseState = ResponseState.idle(.init())
    private let channelLogger: Logger
    
    init(handler: @Sendable @escaping (HTTPServerRequest) async -> HTTPServerResponse) {
        self.handler = handler
        
        var newChannelLogger = Logger(label: "HTTP1RequestChannelHandler")
        newChannelLogger[metadataKey: "lifecycle"] = "HTTP1RequestChannelHandler"
        
        self.channelLogger = newChannelLogger
    }
    
    private enum ChildTaskResult {
        case requestConsumptionFinished
        case responseHandlingFinished
        case requestConsumptionThrew
    }
    
    private func getRequest() async -> HTTPServerRequest {
        return await withCheckedContinuation { cont in
            self.requestState.continuationAwaitingRequestHead(cont)
        }
    }
    
    func process(asyncChannel: NIOAsyncChannel<HTTPServerRequestPart, AsyncHTTPServerResponsePart>) async {
        await withTaskGroup(of: ChildTaskResult.self, returning: Void.self) { group in
            group.addTask {
                let request = await self.getRequest()
                
                await self.handle(request: request, outboundWriter: asyncChannel.outboundWriter)
                
                return .responseHandlingFinished
            }
            
            group.addTask {
                do {
                    for try await part in asyncChannel.inboundStream {
                        await self.process(requestPart: part)
                    }
                    
                    return .requestConsumptionFinished
                } catch {
                    return .requestConsumptionThrew
                }
            }
            
            resultIteration: for await result in group {
                switch result {
                case .requestConsumptionFinished:
                    // this is valid case to finish early and can be ignored
                    continue
                case .responseHandlingFinished:
                    // everything is done
                    break resultIteration
                case .requestConsumptionThrew:
                    // TODO: Handle the error
                    break resultIteration
                }
            }
            
            // make sure everything from the request is cancelled
            group.cancelAll()
        }
    }
    
    private func process(requestPart: HTTPServerRequestPart) async {
        switch requestPart {
        case .head(let requestHead):
            let waitingForRequestBody = self.requestState.requestReceived(requestHead: requestHead)
            self.responseState.waitForResponse(requestHead: requestHead)
        case .body(let byteBuffer):
            let bodyChannel = self.requestState.partialBodyReceived()
            await bodyChannel.send(byteBuffer)
        case .end:
            // this signals that the head and all possible body parts have been received
            self.requestState.requestFullyReceived()
        }
    }
    
    private func handle(request: HTTPServerRequest,
                        outboundWriter: NIOAsyncChannelOutboundWriter<AsyncHTTPServerResponsePart>) async {
        let response = await self.handler(request)
        
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
            let keepAlive = self.responseState.responseFullySent()
            
            if !keepAlive {
                outboundWriter.finish()
            }
        } catch {
            self.channelLogger.error(
                "Error caught while sending body: \(String(describing: error)). Body may not be completely sent.")
        }
    }
}
