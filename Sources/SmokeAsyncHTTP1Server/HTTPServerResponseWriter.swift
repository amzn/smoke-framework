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
// HTTPServerResponseWriter.swift
// SmokeAsyncHTTP1Server
//

import NIOHTTP1
@_spi(AsyncChannel) import NIOCore

public enum HTTPServerResponseWriterAction {
    case updateStatus
    case updateContentType
    case updateBodyLength
    case updateHeaders
    case commit
    case writeBodyPart
    case complete
}

public enum HTTPServerResponseWriterState {
    // The header of the response has not yet been sent, fields such as `responseCode` and `headers`
    // can still be modified
    case notCommitted
    // The header of the response has already been sent, fields such as `responseCode` and `headers`
    // cannot be modified
    case committed
    // The header and full body of the response has already been sent; no further modification of the
    // response is allowed
    case completed
}

private extension AsyncHTTP1ChannelManager.ResponseState {
    var writerState: HTTPServerResponseWriterState {
        switch self {
        case .pendingResponseHead:
            return .notCommitted
        case .pendingResponseBody, .sendingResponseBody:
            return .committed
        case .idle, .waitingForRequestComplete, .waitingForHandlingComplete:
            return .completed
        }
    }
}

public enum HTTPServerResponseWriterError: Error {
    case attemptedActionInInvalidWriterState(action: HTTPServerResponseWriterAction, state: HTTPServerResponseWriterState)
}

public struct HTTPServerResponseWriter: Sendable {
    internal let outboundWriter: NIOAsyncChannelOutboundWriter<AsyncHTTPServerResponsePart>
    internal let channelManager: AsyncHTTP1ChannelManager
    internal let allocator: ByteBufferAllocator
    internal let channelRequestId: UInt64
    
    internal init(outboundWriter: NIOAsyncChannelOutboundWriter<AsyncHTTPServerResponsePart>,
                  channelManager: AsyncHTTP1ChannelManager,
                  allocator: ByteBufferAllocator,
                  channelRequestId: UInt64) {
        self.outboundWriter = outboundWriter
        self.channelManager = channelManager
        self.allocator = allocator
        self.channelRequestId = channelRequestId
    }
}

public extension HTTPServerResponseWriter {
    
    func updateStatus(updateProvider: @Sendable (inout HTTPResponseStatus) throws -> ()) async rethrows {
        try await self.channelManager.updateStatus(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
    
    func setStatus(_ new: HTTPResponseStatus) async {
        await self.updateStatus { current in
            current = new
        }
    }
    
    func updateContentType(updateProvider: @Sendable (inout String?) throws -> ()) async rethrows {
        try await self.channelManager.updateContentType(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
    
    func setContentType(_ new: String?) async {
        await self.updateContentType { current in
            current = new
        }
    }
    
    func updateBodyLength(updateProvider: @Sendable (inout ResponseBodyLength) throws -> ()) async rethrows {
        try await self.channelManager.updateBodyLength(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
    
    func setBodyLength(_ new: ResponseBodyLength) async {
        await self.updateBodyLength { current in
            current = new
        }
    }
    
    func updateHeaders(updateProvider: @Sendable (inout HTTPHeaders) throws -> ()) async rethrows {
        try await self.channelManager.updateHeaders(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
    
    func setHeaders(_ new: HTTPHeaders) async {
        await self.updateHeaders { current in
            current = new
        }
    }
}

public extension HTTPServerResponseWriter {

    func getStatus() async -> HTTPResponseStatus {
        return await self.channelManager.getStatus(channelRequestId: self.channelRequestId)
    }
    
    func getContentType() async -> String? {
        return await self.channelManager.getContentType(channelRequestId: self.channelRequestId)
    }
    
    func getBodyLength() async -> ResponseBodyLength {
        return await self.channelManager.getBodyLength(channelRequestId: self.channelRequestId)
    }
    
    func getHeaders() async -> HTTPHeaders {
        return await self.channelManager.getHeaders(channelRequestId: self.channelRequestId)
    }
}

extension HTTPServerResponseWriter {
    /**
     Commits the response of the writter with any previous values set for status, contentType, bodySize and headers. Will transition
     the status of the writer to `committed`. This will leave the writer in a state where one or more body parts can be added to the writer.
     
     - throws:
     - `attemptedActionInInvalidWriterState` if this function is called after the writer has previously been committed or completed.
     */
    public func commit() async throws {
        // write the head
        let head = await self.channelManager.sendResponseHead(channelRequestId: self.channelRequestId)
            
        try await outboundWriter.write(.head(head))
    }
    
    /**
     Completes writing the response. Will transition
     the status of the writer to `completed`. The response will have been completely sent and no further modification is possible
     
     - throws:
     - `attemptedActionInInvalidWriterState` if this function is called after the writer has either not been previously committed or
                                            has been previously completed.
     */
    public func complete() async throws {
        let keepAlive = await self.channelManager.responseFullySent(channelRequestId: self.channelRequestId)
            
        if !keepAlive {
            self.outboundWriter.finish()
            await self.channelManager.completeChannel(channelRequestId: self.channelRequestId)
        }
    }
}

extension HTTPServerResponseWriter {
    
    /**
     Commits the response of the writter with any previous values set for status, contentType and headers. This function completes the response
     with no body and will transition the status of the writer to `complete`.
     
     - throws:
        - `attemptedActionInInvalidWriterState` if this function is called after the writer has previously been committed or completed.
     */
    public func commitAndComplete() async throws {
        try await self.commit()
        try await self.complete()
    }

    /**
     Commits the response of the writter with any previous values set for status, contentType and headers. This function treats the
     provided `ByteBuffer` as the complete body and will transition the status of the writer to `complete`. If `bodyLength`
     is provided, this will be used as the length of the body, otherwise `readableBytes` of the provided body will.
     
     - parameters:
        - bytes: the `ByteBuffer` that will be used as the body of the response.
     - throws:
        - `attemptedActionInInvalidWriterState` if this function is called after the writer has previously been committed or completed.
     */
    public func commitAndCompleteWith(_ bytes: ByteBuffer,
                                      bodyLength: Int? = nil) async throws {
        await self.setBodyLength(.known(bodyLength ?? bytes.readableBytes))
        
        try await self.commit()
        try await self.bodyPart(bytes)
        try await self.complete()
    }
    
    /**
     Commits the response of the writter with any previous values set for status, contentType and headers. This function treats the
     provided `RandomAccessCollection` as the complete body and will transition the status of the writer to `complete`. If `bodyLength`
     is provided, this will be used as the length of the body, otherwise size of the provided collection will.
     
     - parameters:
        - bytes: the `RandomAccessCollection` that will be used as the body of the response.
     - throws:
        - `attemptedActionInInvalidWriterState` if this function is called after the writer has previously been committed or completed.
     */
    public func commitAndCompleteWith<Bytes: RandomAccessCollection & Sendable>(
        _ bytes: Bytes,
        bodyLength: Int? = nil
    ) async throws where Bytes.Element == UInt8 {
        let buffer = bytes.asByteBuffer(allocator: self.allocator)
        
        try await self.commitAndCompleteWith(buffer, bodyLength: bodyLength)
    }
    
    /**
     Commits the response of the writter with any previous values set for status, contentType and headers. This function treats the
     provided `Sequence` as the complete body and will transition the status of the writer to `complete`. If `bodyLength`
     is provided, this will be used as the length of the body, otherwise size of the provided collection will.
     
     - parameters:
        - bytes: the `Sequence` that will be used as the body of the response.
     - throws:
        - `attemptedActionInInvalidWriterState` if this function is called after the writer has previously been committed or completed.
     */
    public func commitAndCompleteWith<Bytes: Sequence & Sendable>(
        _ bytes: Bytes,
        bodyLength: Int? = nil
    ) async throws where Bytes.Element == UInt8 {
        let buffer = bytes.asByteBuffer(allocator: self.allocator)
        
        try await self.commitAndCompleteWith(buffer, bodyLength: bodyLength)
    }
}

extension HTTPServerResponseWriter {

    /**
     Submits a `ByteBuffer` to the response as a bodt part.
     
     - parameters:
        - bytes: the `ByteBuffer` that will be used as a part of the body of the response.
     - throws:
        - `attemptedActionInInvalidWriterState` if this function is called after the writer has not previously been committed or has been completed.
     */
    public func bodyPart(_ bytes: ByteBuffer) async throws {
        await self.channelManager.sendResponseBodyPart(channelRequestId: self.channelRequestId)
        try await self.outboundWriter.write(.body(bytes))
    }
    
    /**
     Submits a `RandomAccessCollection` to the response as a bodt part.
     
     - parameters:
        - bytes: the `RandomAccessCollection` that will be used as a part of the body of the response.
     - throws:
        - `attemptedActionInInvalidWriterState` if this function is called after the writer has not previously been committed or has been completed.
     */
    public func bodyPart<Bytes: RandomAccessCollection & Sendable>(
        _ bytes: Bytes
    ) async throws where Bytes.Element == UInt8 {
        let buffer = bytes.asByteBuffer(allocator: self.allocator)
        
        try await self.bodyPart(buffer)
    }
    
    /**
     Submits a `Sequence` to the response as a bodt part.
     
     - parameters:
        - bytes: the `Sequence` that will be used as a part of the body of the response.
     - throws:
        - `attemptedActionInInvalidWriterState` if this function is called after the writer has not previously been committed or has been completed.
     */
    public func bodyPart<Bytes: Sequence & Sendable>(
        _ bytes: Bytes
    ) async throws where Bytes.Element == UInt8 {
        let buffer = bytes.asByteBuffer(allocator: self.allocator)
        
        try await self.bodyPart(buffer)
    }
}

private extension Sequence where Element == UInt8 {
    func asByteBuffer(allocator: ByteBufferAllocator) -> ByteBuffer {
        if let buffer = self.withContiguousStorageIfAvailable({ allocator.buffer(bytes: $0) }) {
            // fastpath
            return buffer
        }
        // potentially really slow path
        return allocator.buffer(bytes: self)
    }
}

private extension RandomAccessCollection where Element == UInt8 {
    func asByteBuffer(allocator: ByteBufferAllocator) -> ByteBuffer {
        if let buffer = self.withContiguousStorageIfAvailable({ allocator.buffer(bytes: $0) }) {
            // fastpath
            return buffer
        }
        // potentially really slow path
        return allocator.buffer(bytes: self)
    }
}
