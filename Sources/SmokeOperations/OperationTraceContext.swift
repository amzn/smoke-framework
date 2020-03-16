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
//  OperationTraceContext.swift
//  SmokeOperations
//

import Foundation
import Logging

public protocol OperationTraceContext {
    associatedtype RequestHeadType
    associatedtype ResponseHeadersType
    associatedtype ResponseStatusType
    
    init(requestHead: RequestHeadType, bodyData: Data?)
    
    func handleInwardsRequestStart(requestHead: RequestHeadType, bodyData: Data?, logger: inout Logger, internalRequestId: String)
    
    func handleInwardsRequestComplete(httpHeaders: inout ResponseHeadersType, status: ResponseStatusType, body: (contentType: String, data: Data)?,
                                      logger: Logger, internalRequestId: String)
}
