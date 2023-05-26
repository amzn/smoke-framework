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
// SmokeNoInputNoOutputOperationTests.swift
// SmokeOperationsHTTP1Tests
//

import XCTest
import Foundation
import SwiftMiddleware
import SmokeOperationsHTTP1
import SmokeOperationsHTTP1Server
import SmokeHTTP1ServerMiddleware
@testable import SmokeAsyncHTTP1Server
import ShapeCoding
import NIOPosix
import NIOCore
import NIOHTTP1
import Logging
import AsyncAlgorithms
import SmokeOperations

private extension ExampleContext {
    @Sendable func successOperation() {
        
    }
    
    @Sendable func allowedFailureOperation() throws {
        throw TestErrors.allowedError
    }
    
    @Sendable func notAllowedFailureOperation() throws {
        throw TestErrors.notAllowedError
    }
}

class SmokeNoInputNoOutputOperationProviderTests: XCTestCase {
    var eventLoopGroup: EventLoopGroup!
    
    override func setUpWithError() throws {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDownWithError() throws {
        try self.eventLoopGroup.syncShutdownGracefully()
    }
    
    func testSuccessNoInnerMiddlewareNoOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = ServerMiddlewareStack<RouterType, ExampleContext>(serverName: "TestServer",
                                                                                serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let transformMiddleware = middlewareStack.getNoInputNoOutputTransformingMiddleware(statusOnSuccess: .imATeapot)
        
        middlewareStack.addHandlerForOperation(.exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.successOperation,
                                               allowedErrors: [(TestErrors.allowedError, 404)],
                                               transformMiddleware: transformMiddleware)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        bodyChannel.finish()
        let request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        // the writer should be completed, with the success status but no body parts
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .imATeapot)
        XCTAssertEqual(bodyParts.count, 0)
    }
    
    func testAllowedFailureNoInnerMiddlewareNoOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = ServerMiddlewareStack<RouterType, ExampleContext>(serverName: "TestServer",
                                                                                serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let transformMiddleware = middlewareStack.getNoInputNoOutputTransformingMiddleware(statusOnSuccess: .imATeapot)
        
        middlewareStack.addHandlerForOperation(.exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.allowedFailureOperation,
                                               allowedErrors: [(TestErrors.allowedError, 404)],
                                               transformMiddleware: transformMiddleware)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        bodyChannel.finish()
        let request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        
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
        var middlewareStack = ServerMiddlewareStack<RouterType, ExampleContext>(serverName: "TestServer",
                                                                                serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let transformMiddleware = middlewareStack.getNoInputNoOutputTransformingMiddleware(statusOnSuccess: .imATeapot)
        
        middlewareStack.addHandlerForOperation(.exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.notAllowedFailureOperation,
                                               allowedErrors: [(TestErrors.allowedError, 404)],
                                               transformMiddleware: transformMiddleware)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        bodyChannel.finish()
        let request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        
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
        var middlewareStack = ServerMiddlewareStack<RouterType, ExampleContext>(serverName: "TestServer",
                                                                                serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let originalMiddlewareFlag = AtomicBoolean()
        let transformedMiddlewareFlag = AtomicBoolean()
        
        let outerMiddleware = MiddlewareStack {
            TestOriginalOuterMiddleware(flag: originalMiddlewareFlag)
            
            TestTransformingOuterMiddleware()
            
            TestTransformedOuterMiddleware(flag: transformedMiddlewareFlag)
        }
        
        let transformMiddleware = middlewareStack.getNoInputNoOutputTransformingMiddleware(from: outerMiddleware, statusOnSuccess: .imATeapot)
        
        middlewareStack.addHandlerForOperation(.exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.successOperation,
                                               allowedErrors: [(TestErrors.allowedError, 404)],
                                               outerMiddleware: outerMiddleware,
                                               transformMiddleware: transformMiddleware)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        bodyChannel.finish()
        let request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        let originalMiddlewareFlagValue = await originalMiddlewareFlag.value
        let transformedMiddlewareFlagValue = await transformedMiddlewareFlag.value
        
        // the writer should be completed, with the success status but no body parts
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .imATeapot)
        XCTAssertEqual(bodyParts.count, 0)
        
        XCTAssertTrue(originalMiddlewareFlagValue)
        XCTAssertTrue(transformedMiddlewareFlagValue)
    }
    
    func testSuccessWithInnerMiddlewareNoOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = ServerMiddlewareStack<RouterType, ExampleContext>(serverName: "TestServer",
                                                                                serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let originalMiddlewareFlag = AtomicBoolean()
        let transformedMiddlewareFlag = AtomicBoolean()
        
        let innerMiddleware = MiddlewareStack {
            TestVoidOriginalNoOuterMiddlewareInnerMiddleware(flag: originalMiddlewareFlag)
            
            TestVoidTransformingNoOuterMiddlewareInnerMiddleware()
            
            TestVoidTransformedNoOuterMiddlewareInnerMiddleware(flag: transformedMiddlewareFlag)
        }
        
        let transformMiddleware = middlewareStack.getNoInputNoOutputTransformingMiddleware(statusOnSuccess: .imATeapot)
        
        middlewareStack.addHandlerForOperation(.exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.successOperation,
                                               allowedErrors: [(TestErrors.allowedError, 404)],
                                               innerMiddleware: innerMiddleware,
                                               transformMiddleware: transformMiddleware)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        bodyChannel.finish()
        let request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        let originalMiddlewareFlagValue = await originalMiddlewareFlag.value
        let transformedMiddlewareFlagValue = await transformedMiddlewareFlag.value
        
        // the writer should be completed, with the success status but no body parts
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .imATeapot)
        XCTAssertEqual(bodyParts.count, 0)
        
        XCTAssertTrue(originalMiddlewareFlagValue)
        XCTAssertTrue(transformedMiddlewareFlagValue)
    }
    
    func testSuccessWithInnerMiddlewareWithOuterMiddleware() async throws {
        let serverConfiguration: SmokeServerConfiguration<TestOperations> = .init(eventLoopGroup: self.eventLoopGroup)
        var middlewareStack = ServerMiddlewareStack<RouterType, ExampleContext>(serverName: "TestServer",
                                                                                serverConfiguration: serverConfiguration) { _ in .init() }
        let responseWriter = TestHTTPServerResponseWriter()
        
        let originalOuterMiddlewareFlag = AtomicBoolean()
        let transformedOuterMiddlewareFlag = AtomicBoolean()
        let originalInnerMiddlewareFlag = AtomicBoolean()
        let transformedInnerMiddlewareFlag = AtomicBoolean()
        
        let outerMiddleware = MiddlewareStack {
            TestOriginalOuterMiddleware(flag: originalOuterMiddlewareFlag)
            
            TestTransformingOuterMiddleware()
            
            TestTransformedOuterMiddleware(flag: transformedOuterMiddlewareFlag)
        }
        
        let innerMiddleware = MiddlewareStack {
            TestVoidOriginalInnerMiddleware(flag: originalInnerMiddlewareFlag)
            
            TestVoidTransformingInnerMiddleware()
            
            TestVoidTransformedInnerMiddleware(flag: transformedInnerMiddlewareFlag)
        }
        
        let transformMiddleware = middlewareStack.getNoInputNoOutputTransformingMiddleware(from: outerMiddleware, statusOnSuccess: .imATeapot)
        
        middlewareStack.addHandlerForOperation(.exampleOperation, httpMethod: .POST, operationProvider: ExampleContext.successOperation,
                                               allowedErrors: [(TestErrors.allowedError, 404)],
                                               outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware,
                                               transformMiddleware: transformMiddleware)
        
        let bodyChannel = AsyncThrowingChannel<ByteBuffer, Error>()
        bodyChannel.finish()
        let request = HTTPServerRequest(method: .POST,
                                        uri: TestOperations.exampleOperation.operationPath,
                                        bodyChannel: bodyChannel)
        
        await middlewareStack.handle(request: request, responseWriter: responseWriter)
        
        let bodyParts = await responseWriter.bodyParts
        let writerState = await responseWriter.state
        let status = await responseWriter.status
        
        let originalOuterMiddlewareFlagValue = await originalOuterMiddlewareFlag.value
        let transformedOuterMiddlewareFlagValue = await transformedOuterMiddlewareFlag.value
        let originalInnerMiddlewareFlagValue = await originalInnerMiddlewareFlag.value
        let transformedInnerMiddlewareFlagValue = await transformedInnerMiddlewareFlag.value
        
        // the writer should be completed, with the success status but no body parts
        XCTAssertEqual(writerState, HTTPServerResponseWriterState.completed)
        XCTAssertEqual(status, .imATeapot)
        XCTAssertEqual(bodyParts.count, 0)
        
        XCTAssertTrue(originalOuterMiddlewareFlagValue)
        XCTAssertTrue(transformedOuterMiddlewareFlagValue)
        XCTAssertTrue(originalInnerMiddlewareFlagValue)
        XCTAssertTrue(transformedInnerMiddlewareFlagValue)
    }
}
