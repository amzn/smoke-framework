// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeStaticContextInitializerV2.swift
// SmokeOperationsHTTP1
//

import Logging
import NIO
import SmokeInvocation
import SmokeOperations

/**
  A protocol for initialization SmokeFramework-based applications that require a static context.

  This is a second generation initializer that uses properties on the initializer to create the SelectorType instance
  rather than requiring the user to construct the instance manually. This supports greater abstraction of the
  standard initialization path with `StandardSmokeServerStaticContextInitializer`.
 */
public protocol SmokeStaticContextInitializerV2 {
    associatedtype SelectorType: SmokeHTTP1HandlerSelector

    var handlerSelectorProvider: () -> SelectorType { get }
    var operationsInitializer: (inout SelectorType) -> Void { get }

    var defaultOperationDelegate: SelectorType.DefaultOperationDelegateType { get }
    var serverName: String { get }
    var invocationStrategy: InvocationStrategy { get }
    var defaultLogger: Logger { get }
    var reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer> { get }

    func getInvocationContext() -> SelectorType.ContextType

    func onShutdown() throws
}

public extension SmokeStaticContextInitializerV2 {
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
