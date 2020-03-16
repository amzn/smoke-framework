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
//  OperationDelegate.swift
//  SmokeOperations
//

import Foundation
import Logging

/**
 Delegate protocol for an operation that manages operation handling specific to
 a transport protocol.
 */
public protocol OperationDelegate {
    /// The type of the request head used with this delegate.
    associatedtype RequestHeadType
    /// The trace context type used with this delegate
    associatedtype TraceContextType: OperationTraceContext
    /// The type of response handler used with this delegate.
    associatedtype ResponseHandlerType
    
     /// The `Logging.Logger` to use for logging for this invocation.
    func decorateLoggerForAnonymousRequest(requestLogger: inout Logger)
    
    /**
     Function to handle a successful operation with no response.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForOperationWithNoOutput(requestHead: RequestHeadType, responseHandler: ResponseHandlerType,
                                                invocationContext: SmokeServerInvocationContext<TraceContextType>)
    
    /**
     Function to handle an operation failure.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - operationFailure: The cause of the operation failure.
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForOperationFailure(requestHead: RequestHeadType, operationFailure: OperationFailure,
                                           responseHandler: ResponseHandlerType, invocationContext: SmokeServerInvocationContext<TraceContextType>)
    
    /**
     Function to handle an internal server error.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForInternalServerError(requestHead: RequestHeadType, responseHandler: ResponseHandlerType,
                                              invocationContext: SmokeServerInvocationContext<TraceContextType>)
    
    /**
     Function to handle an invalid operation being requested.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - message: A message corressponding to the failure.
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForInvalidOperation(requestHead: RequestHeadType, message: String,
                                           responseHandler: ResponseHandlerType, invocationContext: SmokeServerInvocationContext<TraceContextType>)
    
    /**
     Function to handle a decoding error.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - message: A message corressponding to the failure.
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForDecodingError(requestHead: RequestHeadType, message: String,
                                        responseHandler: ResponseHandlerType, invocationContext: SmokeServerInvocationContext<TraceContextType>)
    
    /**
     Function to handle a validation error.
 
     - Parameters:
        - requestHead: The original request head corresponding to the operation. Can be used to determine how to
          handle the response (such as requested response type).
        - message: A message corressponding to the failure.
        - responseHander: typically a response handler specific to the transport protocol being used.
        - invocationContext: the context for the current invocation.
     */
    func handleResponseForValidationError(requestHead: RequestHeadType, message: String?,
                                          responseHandler: ResponseHandlerType, invocationContext: SmokeServerInvocationContext<TraceContextType>)
}
