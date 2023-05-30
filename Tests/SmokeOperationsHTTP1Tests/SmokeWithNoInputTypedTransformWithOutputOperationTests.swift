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
// SmokeWithNoInputTypedTransformWithOutputOperationTests.swift
// SmokeOperationsHTTP1Tests
//

import XCTest
import Foundation
import SwiftMiddleware
import SmokeOperationsHTTP1
import SmokeOperationsHTTP1Server
@testable import SmokeAsyncHTTP1Server
import ShapeCoding
import NIOPosix
import NIOCore
import NIOHTTP1
import Logging
import AsyncAlgorithms
import SmokeOperations

@Sendable private func successOperation(_ input: HTTPServerRequest, context: ExampleContext) async throws -> OutputHTTP1Attributes {
    let bodyByteBuffer = try await input.body.collect(upTo: TestValues.maxBodySize)
    let bodyAsString = String(buffer: bodyByteBuffer)
            
    XCTAssertEqual(TestValues.id, bodyAsString)
    
    return .init(bodyColor: .blue, isGreat: true, theHeader: "HEADER")
}

@Sendable private func allowedFailureOperation(_ input: HTTPServerRequest, context: ExampleContext) throws -> OutputHTTP1Attributes {
    throw TestErrors.allowedError
}

@Sendable private func notAllowedFailureOperation(_ input: HTTPServerRequest, context: ExampleContext) throws -> OutputHTTP1Attributes {
    throw TestErrors.notAllowedError
}

class SmokeWithNoInputTypedTransformWithOutputOperationTests: XCTestCase {
    let allocator: ByteBufferAllocator = .init()
    
    var eventLoopGroup: EventLoopGroup!
    
    override func setUpWithError() throws {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDownWithError() throws {
        try self.eventLoopGroup.syncShutdownGracefully()
    }
    
    func testSuccessNoInnerMiddlewareNoOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        middlewareStack.addHandlerForOperation(
            .exampleOperation, httpMethod: .POST, operation: successOperation,
            allowedErrors: [(TestErrors.allowedError, 404)],
            transformMiddleware: JSONTransformingMiddleware.withNoInputTypedTransformAndWithOutput(statusOnSuccess: .imATeapot))
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        // the writer should be completed, with the success status and with the response body as expected
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .imATeapot)
        XCTAssertEqual(bodyParts.count, 1)
    }
    
    func testAllowedFailureNoInnerMiddlewareNoOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        middlewareStack.addHandlerForOperation(
            .exampleOperation, httpMethod: .POST, operation: allowedFailureOperation,
            allowedErrors: [(TestErrors.allowedError, 404)],
            transformMiddleware: JSONTransformingMiddleware.withNoInputTypedTransformAndWithOutput(statusOnSuccess: .imATeapot))
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        // the writer should be completed, with the failure status and the error body
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, HTTPResponseStatus.notFound)
        XCTAssertEqual(bodyParts.count, 1)
        
        var dataBuffer = bodyParts[0]
        let bodyAsString = String(data: dataBuffer.readData(length: dataBuffer.readableBytes)!, encoding: .utf8)!
        XCTAssertTrue(bodyAsString.contains("\"__type\" : \"Allowed\""))
    }
    
    func testNotAllowedFailureNoInnerMiddlewareNoOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        middlewareStack.addHandlerForOperation(
            .exampleOperation, httpMethod: .POST, operation: notAllowedFailureOperation,
            allowedErrors: [(TestErrors.allowedError, 404)],
            transformMiddleware: JSONTransformingMiddleware.withNoInputTypedTransformAndWithOutput(statusOnSuccess: .imATeapot))
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        // the writer should be completed, with the failure status and the error body
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, HTTPResponseStatus.internalServerError)
        XCTAssertEqual(bodyParts.count, 1)
        
        var dataBuffer = bodyParts[0]
        let bodyAsString = String(data: dataBuffer.readData(length: dataBuffer.readableBytes)!, encoding: .utf8)!
        XCTAssertTrue(bodyAsString.contains("\"__type\" : \"InternalError\""))
    }
    
    func testSuccessNoInnerMiddlewareWithOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = TestableServerMiddlewareStack<RouterType, TestHTTPServerResponseWriter, ExampleContext>(
            serverName: "TestServer", serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let originalMiddlewareFlag = AtomicBoolean()
        let transformedMiddlewareFlag = AtomicBoolean()
        
        let outerMiddleware = MiddlewareStack {
            TestOriginalOuterMiddleware(flag: originalMiddlewareFlag)
            
            TestTransformingOuterMiddleware()
            
            TestTransformedOuterMiddleware(flag: transformedMiddlewareFlag)
        }
        
        middlewareStack.addHandlerForOperation(
            .exampleOperation, httpMethod: .POST, operation: successOperation,
            allowedErrors: [(TestErrors.allowedError, 404)],
            outerMiddleware: outerMiddleware,
            transformMiddleware: JSONTransformingMiddleware.withNoInputTypedTransformAndWithOutput(statusOnSuccess: .imATeapot))
        
        let request = getRequest()
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        let originalMiddlewareFlagValue = await originalMiddlewareFlag.value
        let transformedMiddlewareFlagValue = await transformedMiddlewareFlag.value
        
        // the writer should be completed, with the success status and with the response body as expected
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .imATeapot)
        XCTAssertEqual(bodyParts.count, 1)
        
        XCTAssertTrue(originalMiddlewareFlagValue)
        XCTAssertTrue(transformedMiddlewareFlagValue)
    }
    
    private func getRequest() -> HTTPServerRequest {
        let byteBuffer = TestValues.id.data(using: .utf8)!.asByteBuffer(allocator: self.allocator)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        Task {
            await bodyChannel.send(byteBuffer)
            bodyChannel.finish()
        }
        var request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        request.headers.add(name: "theHeader", value: TestValues.header)
        
        return request
    }
}
