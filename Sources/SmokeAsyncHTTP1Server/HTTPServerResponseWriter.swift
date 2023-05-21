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

/**
 Conformance to `HTTPServerResponseWriterProtocol` that uses the `AsyncHTTP1ChannelManager`
 as its backing state mangement.
 */
public struct HTTPServerResponseWriter: Sendable, HTTPServerResponseWriterProtocol { 
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

// MARK: Update Properties
public extension HTTPServerResponseWriter {
    
    func updateStatus(updateProvider: @Sendable (inout HTTPResponseStatus) throws -> ()) async rethrows {
        try await self.channelManager.updateStatus(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
    
    func updateContentType(updateProvider: @Sendable (inout String?) throws -> ()) async rethrows {
        try await self.channelManager.updateContentType(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
    
    func updateBodyLength(updateProvider: @Sendable (inout ResponseBodyLength) throws -> ()) async rethrows {
        try await self.channelManager.updateBodyLength(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
    
    func updateHeaders(updateProvider: @Sendable (inout HTTPHeaders) throws -> ()) async rethrows {
        try await self.channelManager.updateHeaders(channelRequestId: self.channelRequestId, updateProvider: updateProvider)
    }
}

// MARK: Get Properties
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
    
    func getWriterState() async -> HTTPServerResponseWriterState {
        return await self.channelManager.getWriterState(channelRequestId: self.channelRequestId)
    }
}

// MARK: Lifecycle
extension HTTPServerResponseWriter {
    /**
     Commits the response of the writter with any previous values set for status, contentType, bodySize and headers. Will transition
     the status of the writer to `committed`. This will leave the writer in a state where one or more body parts can be added to the writer.
     
     - throws:
        - if the response head fails to be written to the underlying http channel.
     */
    public func commit() async throws {
        // write the head
        let head = await self.channelManager.sendResponseHead(channelRequestId: self.channelRequestId)
            
        try await outboundWriter.write(.head(head))
    }
    
    /**
     Submits a `ByteBuffer` to the response as a body part.
     
     - parameters:
        - bytes: the `ByteBuffer` that will be used as a part of the body of the response.
     - throws:
        - if the response body part fails to be written to the underlying http channel.
     */
    public func bodyPart(_ bytes: ByteBuffer) async throws {
        await self.channelManager.sendResponseBodyPart(channelRequestId: self.channelRequestId)
        try await self.outboundWriter.write(.body(bytes))
    }
    
    /**
     Completes writing the response. Will transition
     the status of the writer to `completed`. The response will have been completely sent and no further modification is possible
     
     - throws:
        - if the response end fails to be written to the underlying http channel.
     */
    public func complete() async throws {
        let keepAlive = await self.channelManager.responseFullySent(channelRequestId: self.channelRequestId)
        try await self.outboundWriter.write(.end(nil))
            
        if !keepAlive {
            self.outboundWriter.finish()
            await self.channelManager.completeChannel(channelRequestId: self.channelRequestId)
        }
    }
}

// MARK: Data Conversion
extension HTTPServerResponseWriter {
    public func asByteBuffer<Bytes: Sequence & Sendable>(_ bytes: Bytes) -> ByteBuffer
    where Bytes.Element == UInt8 {
        return bytes.asByteBuffer(allocator: self.allocator)
    }
    
    public func asByteBuffer<Bytes: RandomAccessCollection & Sendable>(_ bytes: Bytes) -> ByteBuffer
    where Bytes.Element == UInt8 {
        return bytes.asByteBuffer(allocator: self.allocator)
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
