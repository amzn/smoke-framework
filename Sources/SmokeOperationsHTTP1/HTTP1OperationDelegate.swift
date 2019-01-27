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
//  OperationDelegate.swift
//  SmokeOperations
//
import Foundation
import SmokeOperations

/**
 Delegate protocol for an operation that manages operation handling specific to
 a transport protocol.
 */
public protocol HTTP1OperationDelegate: OperationDelegate {
    /**
     Function to retrieve an instance of the InputType from the request. Will throw an error
     if an instance of InputType cannot be constructed from the request.
     */
    func getInputForOperation<InputType: Decodable>(request: RequestType) throws -> InputType
    
    /**
     Function to handle a successful response from an operation.
     
     - Parameters:
     - request: The original request corresponding to the operation. Can be used to determine how to
     handle the response (such as requested response type).
     - output: The instance of the OutputType to send as a response.
     - responseHander: typically a response handler specific to the transport protocol being used.
     */
    func handleResponseForOperation<OutputType: Encodable>(request: RequestType,
                                                           output: OutputType,
                                                           responseHandler: ResponseHandlerType)
}
