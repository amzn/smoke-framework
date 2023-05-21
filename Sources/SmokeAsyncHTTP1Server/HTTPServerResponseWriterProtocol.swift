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
// HTTPServerResponseWriterProtocol.swift
// SmokeAsyncHTTP1Server
//

import NIOHTTP1
import NIOCore

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

/**
 Protocol that describes a writer of a HTTP Server Response.
 */
public protocol HTTPServerResponseWriterProtocol {

    /**
     Update the response status on this writer.
     
     - parameters:
        - updateProvider: a function that provides the current status to mutate.
     */
    func updateStatus(updateProvider: @Sendable (inout HTTPResponseStatus) throws -> ()) async rethrows
    
    /**
     Update the response content type on this writer.
     
     - parameters:
        - updateProvider: a function that provides the current content type to mutate.
     */
    func updateContentType(updateProvider: @Sendable (inout String?) throws -> ()) async rethrows
        
    /**
     Update the response body length on this writer.
     
     - parameters:
        - updateProvider: a function that provides the current body length to mutate.
     */
    func updateBodyLength(updateProvider: @Sendable (inout ResponseBodyLength) throws -> ()) async rethrows
    
    /**
     Update the response headers on this writer.
     
     - parameters:
        - updateProvider: a function that provides the current headers to mutate.
     */
    func updateHeaders(updateProvider: @Sendable (inout HTTPHeaders) throws -> ()) async rethrows

    /**
     Returns the current response status on this writer.
     */
    func getStatus() async -> HTTPResponseStatus
    
    /**
     Returns the current response content type on this writer.
     */
    func getContentType() async -> String?
    
    /**
     Returns the current response body length on this writer.
     */
    func getBodyLength() async -> ResponseBodyLength
    
    /**
     Returns the current response headers on this writer.
     */
    func getHeaders() async -> HTTPHeaders
    
    /**
     Returns the current state of the writer
     */
    func getWriterState() async -> HTTPServerResponseWriterState
    
    /**
     Commits the response of the writter with any previous values set for status, contentType, bodySize and headers. Will transition
     the status of the writer to `committed`. This will leave the writer in a state where one or more body parts can be added to the writer.
     
     - throws:
        - if the response head fails to be written to the underlying http channel.
     */
    func commit() async throws
    
    /**
     Completes writing the response. Will transition the status of the writer to `completed`. The response will have been completely
     sent and no further modification is possible
     
     - throws:
        - if the response end fails to be written to the underlying http channel.
     */
    func complete() async throws
    
    /**
     Submits a `ByteBuffer` to the response as a body part.
     
     - parameters:
        - bytes: the `ByteBuffer` that will be used as a part of the body of the response.
     - throws:
        - if the response body part fails to be written to the underlying http channel.
     */
    func bodyPart(_ bytes: ByteBuffer) async throws
    
    /**
     Converts a sequence of UInt8 to a  `ByteBuffer`.
     */
    func asByteBuffer<Bytes: Sequence & Sendable>(_ bytes: Bytes) -> ByteBuffer
    where Bytes.Element == UInt8
    
    /**
     Converts a `RandomAccessCollection` of UInt8 to a  `ByteBuffer`.
     */
    func asByteBuffer<Bytes: RandomAccessCollection & Sendable>(_ bytes: Bytes) -> ByteBuffer
    where Bytes.Element == UInt8
}

// MARK: Clobber properties
public extension HTTPServerResponseWriterProtocol {
    
    func setStatus(_ new: HTTPResponseStatus) async {
        await self.updateStatus { current in
            current = new
        }
    }
    
    func setContentType(_ new: String?) async {
        await self.updateContentType { current in
            current = new
        }
    }
    
    func setBodyLength(_ new: ResponseBodyLength) async {
        await self.updateBodyLength { current in
            current = new
        }
    }
    
    func setHeaders(_ new: HTTPHeaders) async {
        await self.updateHeaders { current in
            current = new
        }
    }
}

// MARK: Multiple actions on the writer at once.
extension HTTPServerResponseWriterProtocol {
    
    /**
     Commits the response of the writter with any previous values set for status, contentType and headers. This function completes the response
     with no body and will transition the status of the writer to `complete`.
     
     - throws:
        - if the response head or end fails to be written to the underlying http channel.
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
        - if the response head, body or end fails to be written to the underlying http channel.
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
        - if the response head, body or end fails to be written to the underlying http channel.
     */
    public func commitAndCompleteWith<Bytes: RandomAccessCollection & Sendable>(
        _ bytes: Bytes,
        bodyLength: Int? = nil
    ) async throws where Bytes.Element == UInt8 {
        let buffer = self.asByteBuffer(bytes)
        
        try await self.commitAndCompleteWith(buffer, bodyLength: bodyLength)
    }
    
    /**
     Commits the response of the writter with any previous values set for status, contentType and headers. This function treats the
     provided `Sequence` as the complete body and will transition the status of the writer to `complete`. If `bodyLength`
     is provided, this will be used as the length of the body, otherwise size of the provided collection will.
     
     - parameters:
        - bytes: the `Sequence` that will be used as the body of the response.
     - throws:
        - if the response head, body or end fails to be written to the underlying http channel.
     */
    public func commitAndCompleteWith<Bytes: Sequence & Sendable>(
        _ bytes: Bytes,
        bodyLength: Int? = nil
    ) async throws where Bytes.Element == UInt8 {
        let buffer = self.asByteBuffer(bytes)
        
        try await self.commitAndCompleteWith(buffer, bodyLength: bodyLength)
    }
}

// MARK: Body part conversion.
extension HTTPServerResponseWriterProtocol {
    
    /**
     Submits a `RandomAccessCollection` to the response as a body part.
     
     - parameters:
        - bytes: the `RandomAccessCollection` that will be used as a part of the body of the response.
     - throws:
        - if the response body part fails to be written to the underlying http channel.
     */
    public func bodyPart<Bytes: RandomAccessCollection & Sendable>(
        _ bytes: Bytes
    ) async throws where Bytes.Element == UInt8 {
        let buffer = self.asByteBuffer(bytes)
        
        try await self.bodyPart(buffer)
    }
    
    /**
     Submits a `Sequence` to the response as a body part.
     
     - parameters:
        - bytes: the `Sequence` that will be used as a part of the body of the response.
     - throws:
        - if the response body part fails to be written to the underlying http channel.
     */
    public func bodyPart<Bytes: Sequence & Sendable>(
        _ bytes: Bytes
    ) async throws where Bytes.Element == UInt8 {
        let buffer = self.asByteBuffer(bytes)
        
        try await self.bodyPart(buffer)
    }
}
