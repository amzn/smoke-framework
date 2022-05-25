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
// SmokeOperationsSyncTests.swift
// SmokeOperationsTests
//

import XCTest
@testable import SmokeOperationsHTTP1
import SmokeOperations
import NIOHTTP1
import SmokeHTTP1

private func handleExampleOperationVoid(input: ExampleInput, context: ExampleContext) throws {
    // This function intentionally left blank.
}

private func handleExampleHTTP1OperationVoid(input: ExampleHTTP1Input, context: ExampleContext) throws {
    input.validateForTest()
}

private func handleBadOperationVoid(input: ExampleInput, context: ExampleContext) throws {
    throw MyError.theError(reason: "Is bad!")
}

private func handleBadHTTP1OperationVoid(input: ExampleHTTP1Input, context: ExampleContext) throws {
    input.validateForTest()
    throw MyError.theError(reason: "Is bad!")
}

private func handleExampleOperation(input: ExampleInput, context: ExampleContext) throws -> OutputAttributes {
    return OutputAttributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                            isGreat: true)
}

private func handleExampleHTTP1Operation(input: ExampleHTTP1Input, context: ExampleContext) throws -> OutputHTTP1Attributes {
    input.validateForTest()
    return OutputHTTP1Attributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                 isGreat: true,
                                 theHeader: input.theHeader)
}

private func handleBadOperation(input: ExampleInput, context: ExampleContext) throws -> OutputAttributes {
    throw MyError.theError(reason: "Is bad!")
}

private func handleBadHTTP1Operation(input: ExampleHTTP1Input, context: ExampleContext) throws -> OutputHTTP1Attributes {
    input.validateForTest()
    throw MyError.theError(reason: "Is bad!")
}

private let handlerSelector: StandardSmokeHTTP1HandlerSelector<ExampleContext, TestJSONPayloadHTTP1OperationDelegate, TestOperations> = {
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
    
    func testExampleHandler() async throws {
        let response = await verifyPathOutput(uri: "exampleOperation",
                                              body: serializedInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 200)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(OutputAttributes.self,
                                                              from: body.data)
        let expectedOutput = OutputAttributes(bodyColor: .blue, isGreat: true)
        XCTAssertEqual(expectedOutput, output)
    }
    
    func testExampleHandlerWithTokenHeaderQuery() async throws {
        let response = await verifyPathOutput(uri: "exampleoperation/suchToken?theParameter=muchParameter",
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

    func testExampleVoidHandler() async {
        let response = await verifyPathOutput(uri: "exampleNoBodyOperation",
                                              body: serializedInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector)

        let body = response.responseComponents.body
        XCTAssertEqual(response.status.code, 200)
        XCTAssertNil(body)
    }
    
    func testExampleVoidHandlerWithTokenHeaderQuery() async {
        let response = await verifyPathOutput(uri: "exampleNoBodyOperation/suchToken?theParameter=muchParameter",
                                              body: serializedInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector,
                                              additionalHeaders: [("theHeader", "headerValue")])

        let body = response.responseComponents.body
        XCTAssertEqual(response.status.code, 200)
        XCTAssertNil(body)
    }
  
    func testInputValidationError() async throws {
        let response = await verifyPathOutput(uri: "exampleOperation",
                                              body: serializedInvalidInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("ValidationError", output.type)
    }
    
    func testInputValidationErrorWithTokenHeaderQuery() async throws {
        let response = await verifyPathOutput(uri: "exampleOperation/suchToken?theParameter=muchParameter",
                                              body: serializedInvalidInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector,
                                              additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                                   from: body.data)
        
        XCTAssertEqual("ValidationError", output.type)
    }
   
    func testOutputValidationError() async throws {
        let response = await verifyPathOutput(uri: "exampleOperation",
                                              body: serializedAlternateInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 500)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InternalError", output.type)
    }
    
    func testOutputValidationErrorWithTokenHeaderQuery() async throws {
        let response = await verifyPathOutput(uri: "exampleOperation/suchToken?theParameter=muchParameter",
                                              body: serializedAlternateInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector,
                                              additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 500)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                                  from: body.data)
        
        XCTAssertEqual("InternalError", output.type)
    }
    
    func testThrownErrorWithTokenHeaderQuery() async throws {
        try await verifyErrorResponse(uri: "badOperationVoidResponse/suchToken?theParameter=muchParameter",
                                      handlerSelector: handlerSelector,
                                      additionalHeaders: [("theHeader", "headerValue")])
        try await verifyErrorResponse(uri: "badOperation/suchToken?theParameter=muchParameter",
                                      handlerSelector: handlerSelector,
                                      additionalHeaders: [("theHeader", "headerValue")])
    }
    
    func testThrownError() async throws {
        try await verifyErrorResponse(uri: "badOperationVoidResponse", handlerSelector: handlerSelector)
        try await verifyErrorResponse(uri: "badOperation", handlerSelector: handlerSelector)
    }
    
    func testInvalidOperation() async throws {
        let response = await verifyPathOutput(uri: "unknownOperation",
                                              body: serializedAlternateInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testInvalidOperationWithTokenHeaderQuery() async throws {
        let response = await verifyPathOutput(uri: "unknownOperation/suchToken?theParameter=muchParameter",
                                              body: serializedAlternateInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector,
                                              additionalHeaders: [("theHeader", "headerValue")])
        
        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                                  from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testIncorrectHTTPMethodOperation() async throws {
        let response = await verifyPathOutput(uri: "examplegetoperation",
                                              body: serializedAlternateInput.data(using: .utf8)!,
                                              handlerSelector: handlerSelector)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testIncorrectHTTPMethodOperationWithTokenHeaderQuery() async throws {
         let response = await verifyPathOutput(uri: "examplegetoperation/suchToken?theParameter=muchParameter",
                                               body: serializedInput.data(using: .utf8)!,
                                               handlerSelector: handlerSelector,
                                               additionalHeaders: [("theHeader", "headerValue")])
        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
}
