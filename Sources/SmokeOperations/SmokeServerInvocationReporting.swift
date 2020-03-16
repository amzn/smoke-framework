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
//  SmokeServerInvocationReporting.swift
//  SmokeOperations
//

import Foundation
import Logging

/**
 A context related to reporting on the invocation of the SmokeFramework.
 */
public struct SmokeServerInvocationReporting<TraceContextType: OperationTraceContext> {
    public let logger: Logger
    public let internalRequestId: String
    public let traceContext: TraceContextType
    
    public init(logger: Logger, internalRequestId: String, traceContext: TraceContextType) {
        self.logger = logger
        self.internalRequestId = internalRequestId
        self.traceContext = traceContext
    }
}
