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
// AsyncHTTP1ChannelManager_ResponseState.swift
// SmokeAsyncHTTP1Server
//

import Foundation
@_spi(AsyncChannel) import NIOCore
import NIOHTTP1
import AsyncAlgorithms

extension AsyncHTTP1ChannelManager {
    /**
     Internal state variable that tracks the progress of the HTTP Response.
     */
    internal enum ResponseState {
        case idle
        case pendingResponseHead(PendingResponseHead)
        case pendingResponseBody(PendingResponseBody)
        case sendingResponseBody(SendingResponseBody)
        case waitingForRequestComplete(ResponseHead)
        case waitingForHandlingComplete(ResponseHead)
        
        internal struct ResponseHead {
            var status: HTTPResponseStatus
            var contentType: String?
            var bodyLength: ResponseBodyLength
            var headers: HTTPHeaders
            
            init() {
                self.status = .ok
                self.headers = .init()
                self.bodyLength = .unknown
            }
        }
        
        internal struct PendingResponseHead {
            let requestHead: HTTPRequestHead
            var keepAliveStatus: KeepAliveStatus
            var responseHead: ResponseHead
            
            init(requestHead: HTTPRequestHead) {
                self.requestHead = requestHead
                self.keepAliveStatus = KeepAliveStatus(state: requestHead.isKeepAlive)
                self.responseHead = .init()
            }
            
            init(pendingResponseHead: PendingResponseHead, keepAliveStatus: Bool) {
                self.requestHead = pendingResponseHead.requestHead
                self.keepAliveStatus = pendingResponseHead.keepAliveStatus
                
                self.keepAliveStatus.state = keepAliveStatus
                self.responseHead = .init()
            }
        }
        
        internal struct PendingResponseBody {
            let requestHead: HTTPRequestHead
            let keepAliveStatus: KeepAliveStatus
            let responseHead: ResponseHead
            
            init(pendingResponseHead: PendingResponseHead) {
                self.requestHead = pendingResponseHead.requestHead
                self.keepAliveStatus = pendingResponseHead.keepAliveStatus
                self.responseHead = pendingResponseHead.responseHead
            }
            
            init(sendingResponseBody: SendingResponseBody) {
                self.requestHead = sendingResponseBody.requestHead
                self.keepAliveStatus = sendingResponseBody.keepAliveStatus
                self.responseHead = sendingResponseBody.responseHead
            }
            
            init(pendingResponseBody: PendingResponseBody, keepAliveStatus: Bool) {
                self.requestHead = pendingResponseBody.requestHead
                self.keepAliveStatus = pendingResponseBody.keepAliveStatus
                self.responseHead = pendingResponseBody.responseHead
                
                self.keepAliveStatus.state = keepAliveStatus
            }
        }
        
        internal struct SendingResponseBody {
            let requestHead: HTTPRequestHead
            let keepAliveStatus: KeepAliveStatus
            let responseHead: ResponseHead
            
            init(pendingResponseBody: PendingResponseBody) {
                self.requestHead = pendingResponseBody.requestHead
                self.keepAliveStatus = pendingResponseBody.keepAliveStatus
                self.responseHead = pendingResponseBody.responseHead
            }
            
            init(sendingResponseBody: SendingResponseBody) {
                self.requestHead = sendingResponseBody.requestHead
                self.keepAliveStatus = sendingResponseBody.keepAliveStatus
                self.responseHead = sendingResponseBody.responseHead
            }
            
            init(sendingResponseBody: SendingResponseBody, keepAliveStatus: Bool) {
                self.requestHead = sendingResponseBody.requestHead
                self.keepAliveStatus = sendingResponseBody.keepAliveStatus
                self.responseHead = sendingResponseBody.responseHead
                
                self.keepAliveStatus.state = keepAliveStatus
            }
        }
    }
}

extension AsyncHTTP1ChannelManager.ResponseState {
    mutating func waitForResponse(requestHead: HTTPRequestHead) {
        switch self {
        case .idle:
            let pendingResponseHead = PendingResponseHead(requestHead: requestHead)
            self = .pendingResponseHead(pendingResponseHead)
        case .pendingResponseHead, .pendingResponseBody, .sendingResponseBody,
                .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for requestReceived: \(self)")
            
            fatalError()
        }
    }
    
    mutating func updateStatus(updateProvider: @Sendable (inout HTTPResponseStatus) throws -> ()) rethrows {
        switch self {
        case .pendingResponseHead(var pendingResponseHead):
            try updateProvider(&pendingResponseHead.responseHead.status)
            
            self = .pendingResponseHead(pendingResponseHead)
        case .idle, .pendingResponseBody, .sendingResponseBody,
                .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for status update: \(self)")

            fatalError()
        }
    }
    
    mutating func updateContentType(updateProvider: @Sendable (inout String?) throws -> ()) rethrows {
        switch self {
        case .pendingResponseHead(var pendingResponseHead):
            try updateProvider(&pendingResponseHead.responseHead.contentType)
            
            self = .pendingResponseHead(pendingResponseHead)
        case .idle, .pendingResponseBody, .sendingResponseBody,
                .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for content type update: \(self)")

            fatalError()
        }
    }
    
    mutating func updateBodyLength(updateProvider: @Sendable (inout ResponseBodyLength) throws -> ()) rethrows {
        switch self {
        case .pendingResponseHead(var pendingResponseHead):
            try updateProvider(&pendingResponseHead.responseHead.bodyLength)
            
            self = .pendingResponseHead(pendingResponseHead)
        case .idle, .pendingResponseBody, .sendingResponseBody,
                .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for body length update: \(self)")

            fatalError()
        }
    }
    
    mutating func updateHeaders(updateProvider: @Sendable (inout HTTPHeaders) throws -> ()) rethrows {
        switch self {
        case .pendingResponseHead(var pendingResponseHead):
            try updateProvider(&pendingResponseHead.responseHead.headers)
            
            self = .pendingResponseHead(pendingResponseHead)
        case .idle, .pendingResponseBody, .sendingResponseBody,
                .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for headers update: \(self)")

            fatalError()
        }
    }
}

extension AsyncHTTP1ChannelManager.ResponseState {
    
    private func getResponseHead() -> ResponseHead {
        let responseHead: ResponseHead
        switch self {
        case .pendingResponseHead(let pendingResponseHead):
            responseHead = pendingResponseHead.responseHead
        case .pendingResponseBody(let pendingResponseBody):
            responseHead = pendingResponseBody.responseHead
        case .sendingResponseBody(let sendingResponseBody):
            responseHead = sendingResponseBody.responseHead
        case .waitingForRequestComplete(let theResponseHead):
            responseHead = theResponseHead
        case .waitingForHandlingComplete(let theResponseHead):
            responseHead = theResponseHead
        case .idle:
            assertionFailure("Invalid state for request attribute get: \(self)")
            
            fatalError()
        }
        
        return responseHead
    }

    func getStatus() -> HTTPResponseStatus {
        let responseHead = self.getResponseHead()
        
        return responseHead.status
    }
    
    func getContentType() -> String? {
        let responseHead = self.getResponseHead()
        
        return responseHead.contentType
    }
    
    func getBodyLength() -> ResponseBodyLength {
        let responseHead = self.getResponseHead()
        
        return responseHead.bodyLength
    }
    
    func getHeaders() -> HTTPHeaders {
        let responseHead = self.getResponseHead()
        
        return responseHead.headers
    }
}

extension AsyncHTTP1ChannelManager.ResponseState {
    
    mutating func sendResponseHead() -> HTTPResponseHead {
        switch self {
        case .pendingResponseHead(let pendingResponseHead):
            var headers = pendingResponseHead.responseHead.headers
            
            // if there is a content type
            if let contentType = pendingResponseHead.responseHead.contentType {
                // add the content type header
                headers.add(name: HTTP1Headers.contentType, value: contentType)
            }
            
            // add the content length header and write the response head to the response
            if case .known(let contentLength) = pendingResponseHead.responseHead.bodyLength {
                headers.add(name: HTTP1Headers.contentLength, value: "\(contentLength)")
            }
            
            let requestHead = pendingResponseHead.requestHead
            
            let head = HTTPResponseHead(version: requestHead.version,
                                        status: pendingResponseHead.responseHead.status,
                                        headers: headers)
            
            self = .pendingResponseBody(PendingResponseBody(pendingResponseHead: pendingResponseHead))
            
            return head
        case .idle, .pendingResponseBody, .sendingResponseBody,
                .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for response head send: \(self)")

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
        case .idle, .pendingResponseHead, .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for response body part send: \(self)")
            
            fatalError()
        }
    }
    
    mutating func responseFullySent(requestState: inout AsyncHTTP1ChannelManager.RequestState) -> Bool {
        let keepAliveStatus: KeepAliveStatus
        let responseHead: ResponseHead
        switch self {
        case .pendingResponseBody(let pendingResponseBody):
            keepAliveStatus = pendingResponseBody.keepAliveStatus
            responseHead = pendingResponseBody.responseHead
        case .sendingResponseBody(let sendingResponseBody):
            keepAliveStatus = sendingResponseBody.keepAliveStatus
            responseHead = sendingResponseBody.responseHead
        case .idle, .pendingResponseHead, .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for response body fully sent: \(self)")
            
            fatalError()
        }
        
        switch requestState {
        case .idle, .waitingForRequestBody, .receivingRequestBody, .incomingStreamReset:
            self = .waitingForRequestComplete(responseHead)
        case .waitingForResponseComplete:
            self = .waitingForHandlingComplete(responseHead)
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
        case .waitingForRequestComplete, .waitingForHandlingComplete:
            assertionFailure("Invalid state for updateKeepAliveStatus: \(self)")
            
            fatalError()
        }
    }
    
    mutating func confirmFinished() {
        switch self {
        case .waitingForHandlingComplete:
            self = .idle
        case .waitingForRequestComplete:
            // nothing to do
            break
        case .pendingResponseHead, .pendingResponseBody, .sendingResponseBody, .idle:
            assertionFailure("Invalid state for reset: \(self)")
            
            fatalError()
        }
    }
}

