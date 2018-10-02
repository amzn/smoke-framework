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
//  SmokeHTTP1HandlerSelector.swift
//  SmokeOperations
//

import Foundation
import NIOHTTP1

/**
 Protocol that provides the handler to use for an operation using the
 HTTP1 protocol.
 */
public protocol SmokeHTTP1HandlerSelector {
    associatedtype ContextType
    associatedtype OperationDelegateType: OperationDelegate
    
    /**
     Gets the handler to use for an operation with the provided http request
     head.
 
     - Parameters
        - requestHead: the request head of an incoming operation.
     */
    func getHandlerForOperation(_ requestHead: HTTPRequestHead) throws -> OperationHandler<ContextType, OperationDelegateType>
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - httpMethod: the http method to add the handler for.
        - handler: the handler to add.
     */
    mutating func addHandlerForUri(_ uri: String,
                                   httpMethod: HTTPMethod,
                                   handler: OperationHandler<ContextType, OperationDelegateType>)
}
