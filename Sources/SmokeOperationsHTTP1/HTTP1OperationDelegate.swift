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
//  HTTP1OperationDelegate.swift
//  SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations

public enum OperationInputHTTPLocation {
    case body
    case query
    case path
    case headers
}

public enum OperationOutputHTTPLocation {
    case body
    case headers
}

/**
 Delegate protocol for an operation that manages operation handling specific to
 a transport protocol.
 */
public protocol HTTP1OperationDelegate: OperationDelegate {
    /**
     Function to retrieve an instance of the InputType from the request. Will throw an error
     if an instance of InputType cannot be constructed from the request.
     */
    func getInputForOperation<InputType: OperationHTTP1InputProtocol>(requestHead: RequestHeadType, body: Data?) throws -> InputType
    
    /**
     Function to retrieve an instance of the InputType from the request. Will throw an error
     if an instance of InputType cannot be constructed from the request.
     */
    func getInputForOperation<InputType: Decodable>(requestHead: RequestHeadType,
                                                    body: Data?,
                                                    location: OperationInputHTTPLocation) throws -> InputType
    
    /**
     Function to handle a successful response from an operation.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - output: The instance of the OutputType to send as a response.
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForOperation<OutputType: OperationHTTP1OutputProtocol>(
        requestHead: RequestHeadType,
        output: OutputType,
        responseHandler: ResponseHandlerType,
        invocationContext: SmokeServerInvocationContext<TraceContextType>)
    
    /**
     Function to handle a successful response from an operation.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - output: The instance of the OutputType to send as a response.
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForOperation<OutputType: Encodable>(requestHead: RequestHeadType,
                                                           location: OperationOutputHTTPLocation,
                                                           output: OutputType,
                                                           responseHandler: ResponseHandlerType,
                                                           invocationContext: SmokeServerInvocationContext<TraceContextType>)
}
