// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeOperationsAsyncTests.swift
// SmokeOperationsTests
//
import XCTest
@testable import SmokeOperationsHTTP1
import SmokeOperations
import NIOHTTP1
import SmokeHTTP1

func handleExampleOperationVoidAsync(input: ExampleInput, context: ExampleContext,
                                     responseHandler: (Error?) -> ()) throws {
    responseHandler(nil)
}

func handleExampleHTTP1OperationVoidAsync(input: ExampleHTTP1Input, context: ExampleContext,
                                          responseHandler: (Error?) -> ()) throws {
    input.validateForTest()
    responseHandler(nil)
}

func handleBadOperationVoidAsync(input: ExampleInput, context: ExampleContext,
                                responseHandler: (Error?) -> ()) throws {
    let error = MyError.theError(reason: "Is bad!")
    
    responseHandler(error)
}

func handleBadHTTP1OperationVoidAsync(input: ExampleHTTP1Input, context: ExampleContext,
                                      responseHandler: (Error?) -> ()) throws {
    input.validateForTest()
    let error = MyError.theError(reason: "Is bad!")
    
    responseHandler(error)
}

func handleBadOperationVoidAsyncWithThrow(input: ExampleInput, context: ExampleContext,
                                          responseHandler: (Error?) -> ()) throws {
    throw MyError.theError(reason: "Is bad!")
}

func handleBadHTTP1OperationVoidAsyncWithThrow(input: ExampleHTTP1Input, context: ExampleContext,
                                               responseHandler: (Error?) -> ()) throws {
    input.validateForTest()
    throw MyError.theError(reason: "Is bad!")
}

func handleExampleOperationAsync(input: ExampleInput, context: ExampleContext,
                                 responseHandler: (Swift.Result<OutputAttributes, Swift.Error>) -> ()) throws {
    let attributes = OutputAttributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                       isGreat: true)
    
    responseHandler(.success(attributes))
}

func handleExampleHTTP1OperationAsync(input: ExampleHTTP1Input, context: ExampleContext,
                                      responseHandler: (Swift.Result<OutputHTTP1Attributes, Swift.Error>) -> ()) throws {
    input.validateForTest()
    let attributes = OutputHTTP1Attributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                           isGreat: true, theHeader: input.theHeader)
    
    responseHandler(.success(attributes))
}

func handleBadOperationAsync(input: ExampleInput, context: ExampleContext,
                             responseHandler: (Swift.Result<OutputAttributes, Swift.Error>) -> ()) throws {
    let error = MyError.theError(reason: "Is bad!")
    
    responseHandler(.failure(error))
}

func handleBadHTTP1OperationAsync(input: ExampleHTTP1Input, context: ExampleContext,
                                  responseHandler: (Swift.Result<OutputHTTP1Attributes, Swift.Error>) -> ()) throws {
    input.validateForTest()
    let error = MyError.theError(reason: "Is bad!")
    
    responseHandler(.failure(error))
}

func handleBadOperationAsyncWithThrow(input: ExampleInput, context: ExampleContext,
                                      responseHandler: (Swift.Result<OutputAttributes, Swift.Error>) -> ()) throws {
    throw MyError.theError(reason: "Is bad!")
}

func handleBadHTTP1OperationAsyncWithThrow(input: ExampleHTTP1Input, context: ExampleContext,
                                           responseHandler: (Swift.Result<OutputHTTP1Attributes, Swift.Error>) -> ()) throws {
    input.validateForTest()
    throw MyError.theError(reason: "Is bad!")
}

fileprivate let handlerSelector: StandardSmokeHTTP1HandlerSelector<ExampleContext,
        GenericJSONPayloadHTTP1OperationDelegate<TestHttpResponseHandler, TestOperationTraceContext>, TestOperations> = {
    let defaultOperationDelegate = GenericJSONPayloadHTTP1OperationDelegate<TestHttpResponseHandler, TestOperationTraceContext>()
    var newHandlerSelector = StandardSmokeHTTP1HandlerSelector<ExampleContext, GenericJSONPayloadHTTP1OperationDelegate, TestOperations>(
        defaultOperationDelegate: defaultOperationDelegate)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleOperation, httpMethod: .POST,
        operation: handleExampleOperationAsync,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleOperationWithToken, httpMethod: .POST,
        operation: handleExampleHTTP1OperationAsync,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleGetOperation, httpMethod: .GET,
        operation: handleExampleOperationAsync,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleGetOperationWithToken, httpMethod: .GET,
        operation: handleExampleHTTP1OperationAsync,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleNoBodyOperation, httpMethod: .POST,
        operation: handleExampleOperationVoidAsync,
        allowedErrors: allowedErrors,
        inputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleNoBodyOperationWithToken, httpMethod: .POST,
        operation: handleExampleHTTP1OperationVoidAsync,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationVoidResponse, httpMethod: .POST,
        operation: handleBadOperationVoidAsync,
        allowedErrors: allowedErrors,
        inputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationVoidResponseWithToken, httpMethod: .POST,
        operation: handleBadHTTP1OperationVoidAsync,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationVoidResponseWithThrow, httpMethod: .POST,
        operation: handleBadOperationVoidAsyncWithThrow,
        allowedErrors: allowedErrors,
        inputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationVoidResponseWithThrowWithToken, httpMethod: .POST,
        operation: handleBadHTTP1OperationVoidAsyncWithThrow,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperation, httpMethod: .POST,
        operation: handleBadOperationAsync,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationWithToken, httpMethod: .POST,
        operation: handleBadHTTP1OperationAsync,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationWithThrow, httpMethod: .POST,
        operation: handleBadOperationAsync,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationWithThrowWithToken, httpMethod: .POST,
        operation: handleBadHTTP1OperationAsync,
        allowedErrors: allowedErrors)
    
    return newHandlerSelector
}()

class SmokeOperationsHTTP1AsyncTests: XCTestCase {
    
    func testExampleHandler() throws {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 200)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(OutputAttributes.self,
                                                              from: body.data)
        let expectedOutput = OutputAttributes(bodyColor: .blue, isGreat: true)
        XCTAssertEqual(expectedOutput, output)
    }
    
    func testExampleHandlerWithTokenHeaderQuery() throws {
        let response = verifyPathOutput(uri: "exampleoperation/suchToken?theParameter=muchParameter",
                                        body: serializedInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector,
                                        additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 200)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(OutputAttributes.self,
                                                                  from: body.data)
        let expectedOutput = OutputAttributes(bodyColor: .blue, isGreat: true)
        XCTAssertEqual(expectedOutput, output)
    }

    func testExampleVoidHandler() {
        let response = verifyPathOutput(uri: "exampleNoBodyOperation",
                                        body: serializedInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector)

        let body = response.responseComponents.body
        XCTAssertEqual(response.status.code, 200)
        XCTAssertNil(body)
    }
    
    func testExampleVoidHandlerWithTokenHeaderQuery() {
        let response = verifyPathOutput(uri: "exampleNoBodyOperation/suchToken?theParameter=muchParameter",
                                        body: serializedInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector,
                                        additionalHeaders: [("theHeader", "headerValue")])
        
        let body = response.responseComponents.body
        XCTAssertEqual(response.status.code, 200)
        XCTAssertNil(body)
    }
  
    func testInputValidationError() throws {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedInvalidInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("ValidationError", output.type)
    }
    
    func testInputValidationErrorWithTokenHeaderQuery() throws {
        let response = verifyPathOutput(uri: "exampleOperation/suchToken?theParameter=muchParameter",
                                        body: serializedInvalidInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector,
                                        additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                                  from: body.data)
        
        XCTAssertEqual("ValidationError", output.type)
    }
   
    func testOutputValidationError() throws {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedAlternateInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 500)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InternalError", output.type)
    }
    
    func testOutputValidationErrorWithTokenHeaderQuery() throws {
        let response = verifyPathOutput(uri: "exampleOperation/suchToken?theParameter=muchParameter",
                                        body: serializedAlternateInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector,
                                        additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 500)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                                  from: body.data)
        
        XCTAssertEqual("InternalError", output.type)
    }
    
    func testThrownError() throws {
        try verifyErrorResponse(uri: "badOperationVoidResponse", handlerSelector: handlerSelector)
        try verifyErrorResponse(uri: "badOperationVoidResponseWithThrow", handlerSelector: handlerSelector)
        try verifyErrorResponse(uri: "badOperation", handlerSelector: handlerSelector)
        try verifyErrorResponse(uri: "badOperationWithThrow", handlerSelector: handlerSelector)
    }
    
    func testThrownErrorWithTokenHeaderQuery() throws {
        try verifyErrorResponse(uri: "badOperationVoidResponse/suchToken?theParameter=muchParameter",
                                handlerSelector: handlerSelector,
                                additionalHeaders: [("theHeader", "headerValue")])
        try verifyErrorResponse(uri: "badOperationVoidResponseWithThrow/suchToken?theParameter=muchParameter",
                                handlerSelector: handlerSelector,
                                additionalHeaders: [("theHeader", "headerValue")])
        try verifyErrorResponse(uri: "badOperation/suchToken?theParameter=muchParameter",
                                handlerSelector: handlerSelector,
                                additionalHeaders: [("theHeader", "headerValue")])
        try verifyErrorResponse(uri: "badOperationWithThrow/suchToken?theParameter=muchParameter",
                                handlerSelector: handlerSelector,
                                additionalHeaders: [("theHeader", "headerValue")])
    }
    
    func testInvalidOperation() throws {
        let response = verifyPathOutput(uri: "unknownOperation",
                                        body: serializedAlternateInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testInvalidOperationWithTokenHeaderQuery() throws {
        let response = verifyPathOutput(uri: "unknownOperation/suchToken?theParameter=muchParameter",
                                        body: serializedAlternateInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector,
                                        additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                                  from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testIncorrectHTTPMethodOperation() throws {
        let response = verifyPathOutput(uri: "examplegetoperation",
                                        body: serializedAlternateInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testIncorrectHTTPMethodOperationWithTokenHeaderQuery() throws {
        let response = verifyPathOutput(uri: "examplegetoperation/suchToken?theParameter=muchParameter",
                                        body: serializedAlternateInput.data(using: .utf8)!,
                                        handlerSelector: handlerSelector,
                                        additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                                  from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }

    static var allTests = [
        ("testExampleHandler", testExampleHandler),
        ("testExampleHandlerWithTokenHeaderQuery", testExampleHandlerWithTokenHeaderQuery),
        ("testExampleVoidHandler", testExampleVoidHandler),
        ("testExampleVoidHandlerWithTokenHeaderQuery", testExampleVoidHandlerWithTokenHeaderQuery),
        ("testInputValidationError", testInputValidationError),
        ("testInputValidationErrorWithTokenHeaderQuery", testInputValidationErrorWithTokenHeaderQuery),
        ("testOutputValidationError", testOutputValidationError),
        ("testOutputValidationErrorWithTokenHeaderQuery", testOutputValidationErrorWithTokenHeaderQuery),
        ("testThrownError", testThrownError),
        ("testThrownErrorWithTokenHeaderQuery", testThrownErrorWithTokenHeaderQuery),
        ("testInvalidOperation", testInvalidOperation),
        ("testInvalidOperationWithTokenHeaderQuery", testInvalidOperationWithTokenHeaderQuery),
        ("testIncorrectHTTPMethodOperation", testIncorrectHTTPMethodOperation),
        ("testIncorrectHTTPMethodOperationWithTokenHeaderQuery", testIncorrectHTTPMethodOperationWithTokenHeaderQuery),
    ]
}
