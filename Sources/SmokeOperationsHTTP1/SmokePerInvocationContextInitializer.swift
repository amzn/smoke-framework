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
// SmokePerInvocationContextInitializer.swift
// SmokeOperationsHTTP1
//

import NIO
import SmokeInvocation
import SmokeOperations
import Logging

/**
  A protocol for initialization SmokeFramework-based applications that require a per-invocation context.
 */
public protocol SmokePerInvocationContextInitializer {
    associatedtype SelectorType: SmokeHTTP1HandlerSelector
    
    typealias InvocationReportingType = SelectorType.DefaultOperationDelegateType.InvocationReportingType
    
    var handlerSelector: SelectorType { get }
    var serverName: String { get }
    var invocationStrategy: InvocationStrategy { get }
    var defaultLogger: Logger { get }
    var reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer> { get }
        
    func getInvocationContext(invocationReporting: InvocationReportingType) -> SelectorType.ContextType
    
    func onShutdown() throws
}

public extension SmokePerInvocationContextInitializer {
    var serverName: String {
        return "Server"
    }
    
    var invocationStrategy: InvocationStrategy {
        return GlobalDispatchQueueAsyncInvocationStrategy()
    }
    
    var defaultLogger: Logger {
        return Logger(label: "application.initialization")
    }
    
    var reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer> {
        return SmokeReportingConfiguration()
    }
}
