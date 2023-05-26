// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// TestConfiguration.swift
// SmokeOperationsTests
//

import NIOHTTP1
import NIOCore
import SmokeOperations
import SmokeAsyncHTTP1Server
import SmokeHTTP1ServerMiddleware
import SmokeOperationsHTTP1Server
import SmokeOperationsHTTP1
import SwiftMiddleware
import ShapeCoding
import Logging

enum TestOperations: String, OperationIdentity {
    case exampleOperation
    case exampleOperationWithToken
    case exampleGetOperation
    case exampleGetOperationWithToken
    case exampleNoBodyOperation
    case exampleNoBodyOperationWithToken
    case badOperation
    case badOperationWithToken
    case badOperationVoidResponse
    case badOperationVoidResponseWithToken
    case badOperationWithThrow
    case badOperationWithThrowWithToken
    case badOperationVoidResponseWithThrow
    case badOperationVoidResponseWithThrowWithToken
    
    var description: String {
        return rawValue
    }
    
    var operationPath: String {
        switch self {
        case .exampleOperation:
            return "exampleoperation"
        case .exampleOperationWithToken:
            return "exampleoperation/{theToken}"
        case .exampleGetOperation:
            return "examplegetoperation"
        case .exampleGetOperationWithToken:
            return "examplegetoperation/{theToken}"
        case .exampleNoBodyOperation:
            return "examplenobodyoperation"
        case .exampleNoBodyOperationWithToken:
            return "examplenobodyoperation/{theToken}"
        case .badOperation:
            return "badoperation"
        case .badOperationWithToken:
            return "badoperation/{theToken}"
        case .badOperationVoidResponse:
            return "badoperationvoidresponse"
        case .badOperationVoidResponseWithToken:
            return "badoperationvoidresponse/{theToken}"
        case .badOperationWithThrow:
            return "badoperationwiththrow"
        case .badOperationWithThrowWithToken:
            return "badoperationwiththrow/{theToken}"
        case .badOperationVoidResponseWithThrow:
            return "badoperationvoidresponsewiththrow"
        case .badOperationVoidResponseWithThrowWithToken:
            return "badoperationvoidresponsewiththrow/{theToken}"
        }
    }
}

struct TestMiddlewareContext: ContextWithPathShape &
                              ContextWithMutableLogger &
                              ContextWithHTTPServerRequestHead &
                              ContextWithMutableRequestId &
                              ContextWithOperationIdentifer {
    let operationIdentifer: TestOperations
    let pathShape: ShapeCoding.Shape
    var logger: Logging.Logger?
    let httpServerRequestHead: SmokeOperationsHTTP1.HTTPServerRequestHead
    var internalRequestId: String?
}

struct TestMiddlewareContext2: ContextWithPathShape &
                              ContextWithMutableLogger &
                              ContextWithHTTPServerRequestHead &
                              ContextWithMutableRequestId &
                              ContextWithOperationIdentifer {
    let operationIdentifer: TestOperations
    let pathShape: ShapeCoding.Shape
    var logger: Logging.Logger?
    let httpServerRequestHead: SmokeOperationsHTTP1.HTTPServerRequestHead
    var internalRequestId: String?
}

enum TestHTTPServerResponseWriterError: Error {
    case invalidStateToCommitFrom(HTTPServerResponseWriterState)
    case invalidStateToCompleteFrom(HTTPServerResponseWriterState)
}

actor TestHTTPServerResponseWriter: HTTPServerResponseWriterProtocol {
    var bodyParts: [ByteBuffer] = []
    var status: HTTPResponseStatus = .ok
    var contentType: String?
    var bodyLength: ResponseBodyLength = .unknown
    var headers: HTTPHeaders = .init()
    var state: HTTPServerResponseWriterState = .notCommitted
    nonisolated internal let allocator: ByteBufferAllocator = .init()
    
    func bodyPart(_ bytes: ByteBuffer) async throws {
        self.bodyParts.append(bytes)
    }
    
    func updateStatus(updateProvider: @Sendable (inout HTTPResponseStatus) throws -> ()) async rethrows {
        try updateProvider(&self.status)
    }
    
    func updateContentType(updateProvider: @Sendable (inout String?) throws -> ()) async rethrows {
        try updateProvider(&self.contentType)
    }
    
    func updateBodyLength(updateProvider: @Sendable (inout ResponseBodyLength) throws -> ()) async rethrows {
        try updateProvider(&self.bodyLength)
    }
    
    func updateHeaders(updateProvider: @Sendable (inout HTTPHeaders) throws -> ()) async rethrows {
        try updateProvider(&self.headers)
    }
    
    func getStatus() async -> HTTPResponseStatus {
        return self.status
    }
    
    func getContentType() async -> String? {
        return self.contentType
    }
    
    func getBodyLength() async -> ResponseBodyLength {
        return self.bodyLength
    }
    
    func getHeaders() async -> HTTPHeaders {
        return self.headers
    }
    
    func getWriterState() async -> HTTPServerResponseWriterState {
        return self.state
    }
    
    func commit() async throws {
        switch self.state {
        case .notCommitted:
            self.state = .committed
        case .committed, .completed:
            throw TestHTTPServerResponseWriterError.invalidStateToCommitFrom(self.state)
        }
    }
    
    func complete() async throws {
        switch self.state {
        case .committed:
            self.state = .completed
        case .notCommitted, .completed:
            throw TestHTTPServerResponseWriterError.invalidStateToCompleteFrom(self.state)
        }
    }
}

// MARK: Data Conversion
extension TestHTTPServerResponseWriter {
    nonisolated public func asByteBuffer<Bytes: Sequence & Sendable>(_ bytes: Bytes) -> ByteBuffer
    where Bytes.Element == UInt8 {
        return bytes.asByteBuffer(allocator: self.allocator)
    }
    
    nonisolated public func asByteBuffer<Bytes: RandomAccessCollection & Sendable>(_ bytes: Bytes) -> ByteBuffer
    where Bytes.Element == UInt8 {
        return bytes.asByteBuffer(allocator: self.allocator)
    }
}

struct TestHTTPServerResponseWriter2: HTTPServerResponseWriterProtocol {
    let wrapped: TestHTTPServerResponseWriter
    
    init(wrapped: TestHTTPServerResponseWriter) {
        self.wrapped = wrapped
    }
    
    func bodyPart(_ bytes: ByteBuffer) async throws {
        try await self.wrapped.bodyPart(bytes)
    }
    
    func updateStatus(updateProvider: @Sendable (inout HTTPResponseStatus) throws -> ()) async rethrows {
        try await self.wrapped.updateStatus(updateProvider: updateProvider)
    }
    
    func updateContentType(updateProvider: @Sendable (inout String?) throws -> ()) async rethrows {
        try await self.wrapped.updateContentType(updateProvider: updateProvider)
    }
    
    func updateBodyLength(updateProvider: @Sendable (inout ResponseBodyLength) throws -> ()) async rethrows {
        try await self.wrapped.updateBodyLength(updateProvider: updateProvider)
    }
    
    func updateHeaders(updateProvider: @Sendable (inout HTTPHeaders) throws -> ()) async rethrows {
        try await self.wrapped.updateHeaders(updateProvider: updateProvider)
    }
    
    func getStatus() async -> HTTPResponseStatus {
        return await self.wrapped.getStatus()
    }
    
    func getContentType() async -> String? {
        return await self.wrapped.getContentType()
    }
    
    func getBodyLength() async -> ResponseBodyLength {
        return await self.wrapped.getBodyLength()
    }
    
    func getHeaders() async -> HTTPHeaders {
        return await self.wrapped.getHeaders()
    }
    
    func getWriterState() async -> HTTPServerResponseWriterState {
        return await self.wrapped.getWriterState()
    }
    
    func commit() async throws {
        try await self.wrapped.commit()
    }
    
    func complete() async throws {
        try await self.wrapped.complete()
    }
    
    func asByteBuffer<Bytes>(_ bytes: Bytes) -> NIOCore.ByteBuffer where Bytes : Sendable, Bytes : Sequence, Bytes.Element == UInt8 {
        return self.wrapped.asByteBuffer(bytes)
    }
}

struct TestVoidResponseWriter<WrappedWrappedWriter: HTTPServerResponseWriterProtocol>: TypedOutputWriterProtocol {
    typealias OutputType = Void
    
    let wrapped: VoidResponseWriter<WrappedWrappedWriter>
    
    func write(_ new: Void) async throws {
        try await self.wrapped.write(new)
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

struct TestTransformingOuterMiddleware: TransformingMiddlewareProtocol {
    func handle(_ input: HTTPServerRequest,
                outputWriter: TestHTTPServerResponseWriter,
                context: BasicServerRouterMiddlewareContext<TestOperations>,
                next: (HTTPServerRequest, TestHTTPServerResponseWriter2, TestMiddlewareContext) async throws -> Void) async throws {
        let newContext: TestMiddlewareContext = .init(operationIdentifer: context.operationIdentifer,
                                                      pathShape: context.pathShape,
                                                      logger: context.logger,
                                                      httpServerRequestHead: context.httpServerRequestHead,
                                                      internalRequestId: context.internalRequestId)
        try await next(input, .init(wrapped: outputWriter), newContext)
    }
}

struct TestVoidTransformingNoOuterMiddlewareInnerMiddleware: TransformingMiddlewareProtocol {
    func handle(_ input: Void,
                outputWriter: VoidResponseWriter<TestHTTPServerResponseWriter>,
                context: BasicServerRouterMiddlewareContext<TestOperations>,
                next: (Void, TestVoidResponseWriter<TestHTTPServerResponseWriter>, TestMiddlewareContext2) async throws -> Void) async throws {
        let newContext: TestMiddlewareContext2 = .init(operationIdentifer: context.operationIdentifer,
                                                      pathShape: context.pathShape,
                                                      logger: context.logger,
                                                      httpServerRequestHead: context.httpServerRequestHead,
                                                      internalRequestId: context.internalRequestId)
        try await next(input, .init(wrapped: outputWriter), newContext)
    }
}

struct TestVoidTransformingInnerMiddleware: TransformingMiddlewareProtocol {
    func handle(_ input: Void,
                outputWriter: VoidResponseWriter<TestHTTPServerResponseWriter2>,
                context: TestMiddlewareContext,
                next: (Void, TestVoidResponseWriter<TestHTTPServerResponseWriter2>, TestMiddlewareContext2) async throws -> Void) async throws {
        let newContext: TestMiddlewareContext2 = .init(operationIdentifer: context.operationIdentifer,
                                                      pathShape: context.pathShape,
                                                      logger: context.logger,
                                                      httpServerRequestHead: context.httpServerRequestHead,
                                                      internalRequestId: context.internalRequestId)
        try await next(input, .init(wrapped: outputWriter), newContext)
    }
}

struct TestOriginalOuterMiddleware: MiddlewareProtocol {
    typealias Input = HTTPServerRequest
    typealias OutputWriter = TestHTTPServerResponseWriter
    typealias Context = BasicServerRouterMiddlewareContext<TestOperations>
    
    let flag: AtomicBoolean
    
    func handle(_ input: HTTPServerRequest,
                outputWriter: TestHTTPServerResponseWriter,
                context: BasicServerRouterMiddlewareContext<TestOperations>,
                next: (HTTPServerRequest, TestHTTPServerResponseWriter, BasicServerRouterMiddlewareContext<TestOperations>) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
        
        await self.flag.set()
    }
}

struct TestVoidOriginalNoOuterMiddlewareInnerMiddleware: MiddlewareProtocol {
    typealias Input = Void
    typealias OutputWriter = VoidResponseWriter<TestHTTPServerResponseWriter>
    typealias Context = BasicServerRouterMiddlewareContext<TestOperations>
    
    let flag: AtomicBoolean
    
    func handle(_ input: Void,
                outputWriter: VoidResponseWriter<TestHTTPServerResponseWriter>,
                context: BasicServerRouterMiddlewareContext<TestOperations>,
                next: (Void, VoidResponseWriter<TestHTTPServerResponseWriter>, BasicServerRouterMiddlewareContext<TestOperations>) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
        
        await self.flag.set()
    }
}

struct TestVoidOriginalInnerMiddleware: MiddlewareProtocol {
    typealias Input = Void
    typealias OutputWriter = VoidResponseWriter<TestHTTPServerResponseWriter2>
    typealias Context = TestMiddlewareContext
    
    let flag: AtomicBoolean
    
    func handle(_ input: Void,
                outputWriter: VoidResponseWriter<TestHTTPServerResponseWriter2>,
                context: TestMiddlewareContext,
                next: (Void, VoidResponseWriter<TestHTTPServerResponseWriter2>, TestMiddlewareContext) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
        
        await self.flag.set()
    }
}

struct TestTransformedOuterMiddleware: MiddlewareProtocol {
    typealias Input = HTTPServerRequest
    typealias OutputWriter = TestHTTPServerResponseWriter2
    typealias Context = TestMiddlewareContext
    
    let flag: AtomicBoolean
    
    func handle(_ input: HTTPServerRequest,
                outputWriter: TestHTTPServerResponseWriter2,
                context: TestMiddlewareContext,
                next: (HTTPServerRequest, TestHTTPServerResponseWriter2, TestMiddlewareContext) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
        
        await self.flag.set()
    }
}

struct TestVoidTransformedNoOuterMiddlewareInnerMiddleware: MiddlewareProtocol {
    typealias Input = Void
    typealias OutputWriter = TestVoidResponseWriter<TestHTTPServerResponseWriter>
    typealias Context = TestMiddlewareContext2
    
    let flag: AtomicBoolean
    
    func handle(_ input: Void,
                outputWriter: TestVoidResponseWriter<TestHTTPServerResponseWriter>,
                context: TestMiddlewareContext2,
                next: (Void, TestVoidResponseWriter<TestHTTPServerResponseWriter>, TestMiddlewareContext2) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
        
        await self.flag.set()
    }
}

struct TestVoidTransformedInnerMiddleware: MiddlewareProtocol {
    typealias Input = Void
    typealias OutputWriter = TestVoidResponseWriter<TestHTTPServerResponseWriter2>
    typealias Context = TestMiddlewareContext2
    
    let flag: AtomicBoolean
    
    func handle(_ input: Void,
                outputWriter: TestVoidResponseWriter<TestHTTPServerResponseWriter2>,
                context: TestMiddlewareContext2,
                next: (Void, TestVoidResponseWriter<TestHTTPServerResponseWriter2>, TestMiddlewareContext2) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
        
        await self.flag.set()
    }
}

actor TestTypedOutputWriter<OutputType>: TypedOutputWriterProtocol {
    var result: OutputType?
    
    func write(_ new: OutputType) async throws {
        self.result = new
    }
}

typealias RouterType = BasicServerRouter<SmokeMiddlewareContext, BasicServerRouterMiddlewareContext<TestOperations>,
                                                 TestOperations, TestHTTPServerResponseWriter>

enum TestErrors: SmokeReturnableError {
    case allowedError
    case notAllowedError
    
    var description: String {
        switch self {
        case .allowedError:
            return "Allowed"
        case .notAllowedError:
            return "NotAllowed"
        }
    }
}

actor AtomicBoolean {
    var value: Bool = false
    
    func set(_ new: Bool = true) {
        self.value = new
    }
}

struct ExampleContext {
    
}
