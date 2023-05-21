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
// AsyncHTTP1ChannelManager_RequestState.swift
// SmokeAsyncHTTP1Server
//

import Foundation
@_spi(AsyncChannel) import NIOCore
import NIOHTTP1
import AsyncAlgorithms

extension AsyncHTTP1ChannelManager {
    /**
     Internal state variable that tracks the progress of the HTTP Request.
     */
    internal enum RequestState {
        case idle
        case waitingForRequestBody(WaitingForRequestBody)
        case receivingRequestBody(ReceivingRequestBody)
        case waitingForResponseComplete
        case incomingStreamReset
        
        internal struct WaitingForRequestBody {
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
        
        internal struct ReceivingRequestBody {
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
    }
}

extension AsyncHTTP1ChannelManager.RequestState {
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

    mutating func requestFullyReceived(responseState: inout AsyncHTTP1ChannelManager.ResponseState) {
        let bodyChannel: AsyncThrowingChannel<ByteBuffer, Error>?
        
        let nextState: Self
        switch responseState {
        case .idle, .pendingResponseHead, .pendingResponseBody, .sendingResponseBody:
            nextState = .waitingForResponseComplete
        case .waitingForRequestComplete, .waitingForHandlingComplete:
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
        case .idle, .waitingForResponseComplete, .incomingStreamReset:
            // nothing to do
            return
        case .waitingForRequestBody(let state):
            state.bodyChannel.finish()
        case .receivingRequestBody(let state):
            state.bodyChannel.finish()
        }
        
        self = .incomingStreamReset
    }
}

