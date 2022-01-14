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
//  SmokeHTTP1HandlerSelector.swift
//  SmokeOperationsHTTP1
//
import Foundation
import SmokeOperations
import NIOHTTP1
import ShapeCoding
import Logging

/**
 Protocol that provides the handler to use for an operation using the
 HTTP1 protocol.
 */
public protocol SmokeHTTP1HandlerSelector {
    associatedtype ContextType
    associatedtype DefaultOperationDelegateType: HTTP1OperationDelegate
    associatedtype OperationIdentifer: OperationIdentity
    
    typealias InvocationReportingType = DefaultOperationDelegateType.InvocationReportingType
    typealias RequestHeadType = DefaultOperationDelegateType.RequestHeadType
    typealias ResponseHandlerType = DefaultOperationDelegateType.ResponseHandlerType
    
    /// Get the instance of the Default OperationDelegate type
    var defaultOperationDelegate: DefaultOperationDelegateType { get }
    
    var serverName: String { get }
    var reportingConfiguration: SmokeReportingConfiguration<OperationIdentifer> { get }
    
    /**
     Gets the handler to use for an operation with the provided http request
     head.
 
     - Parameters
        - requestHead: the request head of an incoming operation.
     */
    func getHandlerForOperation(_ uri: String, httpMethod: HTTPMethod, requestLogger: Logger) throws
        -> (OperationHandler<ContextType, RequestHeadType, InvocationReportingType, ResponseHandlerType, OperationIdentifer>, Shape)
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - handler: the handler to add.
     */
    mutating func addHandlerForOperation(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        handler: OperationHandler<ContextType, RequestHeadType, InvocationReportingType, ResponseHandlerType, OperationIdentifer>)
}
