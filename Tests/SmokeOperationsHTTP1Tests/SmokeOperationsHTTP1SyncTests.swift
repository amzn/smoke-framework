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
// SmokeOperationsSyncTests.swift
// SmokeOperationsTests
//
import XCTest
@testable import SmokeOperationsHTTP1
import SmokeOperations
import NIOHTTP1
import SmokeHTTP1

func handleExampleOperationVoid(input: ExampleInput, context: ExampleContext) throws {
    // This function intentionally left blank.
}

func handleExampleHTTP1OperationVoid(input: ExampleHTTP1Input, context: ExampleContext) throws {
    input.validateForTest()
}

func handleBadOperationVoid(input: ExampleInput, context: ExampleContext) throws {
    throw MyError.theError(reason: "Is bad!")
}

func handleBadHTTP1OperationVoid(input: ExampleHTTP1Input, context: ExampleContext) throws {
    input.validateForTest()
    throw MyError.theError(reason: "Is bad!")
}

func handleExampleOperation(input: ExampleInput, context: ExampleContext) throws -> OutputAttributes {
    return OutputAttributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                            isGreat: true)
}

func handleExampleHTTP1Operation(input: ExampleHTTP1Input, context: ExampleContext) throws -> OutputHTTP1Attributes {
    input.validateForTest()
    return OutputHTTP1Attributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                 isGreat: true,
                                 theHeader: input.theHeader)
}

func handleBadOperation(input: ExampleInput, context: ExampleContext) throws -> OutputAttributes {
    throw MyError.theError(reason: "Is bad!")
}

func handleBadHTTP1Operation(input: ExampleHTTP1Input, context: ExampleContext) throws -> OutputHTTP1Attributes {
    input.validateForTest()
    throw MyError.theError(reason: "Is bad!")
}

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

typealias TestJSONPayloadHTTP1OperationDelegate = GenericJSONPayloadHTTP1OperationDelegate<TestHttpResponseHandler, TestOperationTraceContext>

fileprivate let handlerSelector: StandardSmokeHTTP1HandlerSelector<ExampleContext, TestJSONPayloadHTTP1OperationDelegate, TestOperations> = {
    var newHandlerSelector = StandardSmokeHTTP1HandlerSelector<ExampleContext, TestJSONPayloadHTTP1OperationDelegate, TestOperations>(
        defaultOperationDelegate: GenericJSONPayloadHTTP1OperationDelegate())
    newHandlerSelector.addHandlerForOperation(
        .exampleOperation, httpMethod: .POST,
        operation: handleExampleOperation,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleOperationWithToken, httpMethod: .POST,
        operation: handleExampleHTTP1Operation,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleGetOperation, httpMethod: .GET,
        operation: handleExampleOperation,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleGetOperationWithToken, httpMethod: .GET,
        operation: handleExampleHTTP1Operation,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleNoBodyOperation, httpMethod: .POST,
        operation: handleExampleOperationVoid,
        allowedErrors: allowedErrors,
        inputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .exampleNoBodyOperationWithToken, httpMethod: .POST,
        operation: handleExampleHTTP1OperationVoid,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperation, httpMethod: .POST,
        operation: handleBadOperation,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationWithToken, httpMethod: .POST,
        operation: handleBadHTTP1Operation,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationVoidResponse, httpMethod: .POST,
        operation: handleBadOperationVoid,
        allowedErrors: allowedErrors,
        inputLocation: .body)
    
    newHandlerSelector.addHandlerForOperation(
        .badOperationVoidResponseWithToken, httpMethod: .POST,
        operation: handleBadHTTP1OperationVoid,
        allowedErrors: allowedErrors)
    
    return newHandlerSelector
}()

class SmokeOperationsHTTP1SyncTests: XCTestCase {
    
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
        let output = try JSONDecoder.getFrameworkDecoder().decode(OutputBodyAttributes.self,
                                                              from: body.data)
        let expectedOutput = OutputBodyAttributes(bodyColor: .blue, isGreat: true)
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
    
    func testThrownErrorWithTokenHeaderQuery() throws {
        try verifyErrorResponse(uri: "badOperationVoidResponse/suchToken?theParameter=muchParameter",
                                handlerSelector: handlerSelector,
                                additionalHeaders: [("theHeader", "headerValue")])
        try verifyErrorResponse(uri: "badOperation/suchToken?theParameter=muchParameter",
                                handlerSelector: handlerSelector,
                                additionalHeaders: [("theHeader", "headerValue")])
    }
    
    func testThrownError() throws {
        try verifyErrorResponse(uri: "badOperationVoidResponse", handlerSelector: handlerSelector)
        try verifyErrorResponse(uri: "badOperation", handlerSelector: handlerSelector)
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
                                         body: serializedInput.data(using: .utf8)!,
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
        ("testIncorrectHTTPMethodOperationWithTokenHeaderQuery",
         testIncorrectHTTPMethodOperationWithTokenHeaderQuery)
    ]
}
