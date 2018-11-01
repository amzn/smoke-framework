// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// main.swift
// SmokeAPI
//

import Foundation
import SmokeHTTP1
import SmokeOperations
import LoggerAPI

struct MyApplicationContext {}

typealias HandlerSelectorType =
    StandardSmokeHTTP1HandlerSelector<MyApplicationContext, JSONPayloadHTTP1OperationDelegate>

func handleExampleOperationAsync(input: ExampleInput, context: MyApplicationContext,
                                 responseHandler: (SmokeResult<ExampleOutput>) -> ()) throws {
    
    let attributes = ExampleOutput(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                      isGreat: true)
    
    responseHandler(.response(attributes))
}

let allowedErrors = [(MyError.theError(reason: "MyError"), 400)]

func createHandlerSelector() -> HandlerSelectorType {
    
    var newHandlerSelector = HandlerSelectorType()
    
    newHandlerSelector.addHandlerForUri("/postexample", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleExampleOperationAsync,
                                                                  allowedErrors: allowedErrors))
    
    return newHandlerSelector
}

do {
    try SmokeHTTP1Server.startAsOperationServer(
        withHandlerSelector: createHandlerSelector(),
        andContext: MyApplicationContext(),
        defaultOperationDelegate: JSONPayloadHTTP1OperationDelegate())
} catch {
    Log.error("Unable to start Operation Server: '\(error)'")
}
