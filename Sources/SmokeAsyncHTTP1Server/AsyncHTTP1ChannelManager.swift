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
    private let handler: @Sendable (HTTPServerRequest, HTTPServerResponseWriter) async -> ()
    private let requestChannel: AsyncThrowingChannel<HTTPServerRequest, Error>
    
    private var requestState = RequestState.idle
    private var responseState = ResponseState.idle
    private var channelRequestId: UInt64 = 0
    private let channelLogger: Logger
    
    init(handler: @Sendable @escaping (HTTPServerRequest, HTTPServerResponseWriter) async -> ()) {
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
        self.channelRequestId += 1
        let allocator: ByteBufferAllocator = .init()
        let writer = HTTPServerResponseWriter(outboundWriter: outboundWriter, channelManager: self,
                                              allocator: allocator, channelRequestId: self.channelRequestId)
        await self.handler(request, writer)
        
        self.requestState.confirmFinished()
        self.responseState.confirmFinished()
    }
}

extension AsyncHTTP1ChannelManager {
    
    func updateStatus(channelRequestId: UInt64,
                      updateProvider: @Sendable (inout HTTPResponseStatus) throws -> ()) rethrows {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        try self.responseState.updateStatus(updateProvider: updateProvider)
    }
    
    func updateContentType(channelRequestId: UInt64,
                           updateProvider: @Sendable (inout String?) throws -> ()) rethrows {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        try self.responseState.updateContentType(updateProvider: updateProvider)
    }
    
    func updateBodyLength(channelRequestId: UInt64,
                          updateProvider: @Sendable (inout ResponseBodyLength) throws -> ()) rethrows {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        try self.responseState.updateBodyLength(updateProvider: updateProvider)
    }
    
    func updateHeaders(channelRequestId: UInt64,
                       updateProvider: @Sendable (inout HTTPHeaders) throws -> ()) rethrows {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        try self.responseState.updateHeaders(updateProvider: updateProvider)
    }
}

extension AsyncHTTP1ChannelManager {

    func getStatus(channelRequestId: UInt64) -> HTTPResponseStatus {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        return self.responseState.getStatus()
    }
    
    func getContentType(channelRequestId: UInt64) -> String? {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        return self.responseState.getContentType()
    }
    
    func getBodyLength(channelRequestId: UInt64) -> ResponseBodyLength {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        return self.responseState.getBodyLength()
    }
    
    func getHeaders(channelRequestId: UInt64) -> HTTPHeaders {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        return self.responseState.getHeaders()
    }
}
    
extension AsyncHTTP1ChannelManager {
    
    internal func sendResponseHead(channelRequestId: UInt64) -> HTTPResponseHead {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        return self.responseState.sendResponseHead()
    }
    
    internal func sendResponseBodyPart(channelRequestId: UInt64) {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        self.responseState.sendResponseBodyPart()
    }
    
    internal func responseFullySent(channelRequestId: UInt64) -> Bool {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        return self.responseState.responseFullySent(requestState: &self.requestState)
    }
    
    internal func completeChannel(channelRequestId: UInt64) {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        self.requestChannel.finish()
    }
    
    internal func getWriterState(channelRequestId: UInt64) -> HTTPServerResponseWriterState {
        guard self.channelRequestId == channelRequestId else {
            assertionFailure("Attempted to use stale request on channel.")
            
            fatalError()
        }
        
        return self.responseState.getWriterState()
    }
}
