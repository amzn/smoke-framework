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
// StandardSmokeServerPerInvocationContextInitializer.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeHTTP1
import SmokeOperations
import SmokeOperationsHTTP1

/**
  A protocol that is derived from `SmokeServerPerInvocationContextInitializerV2` that uses the `StandardSmokeHTTP1HandlerSelector`
  type as the `SelectorType` and `JSONPayloadHTTP1OperationDelegate` as the `DefaultOperationDelegateType`.

  This reduces the configuration required for applications that use these standard components.
 */
public protocol StandardJSONSmokeServerPerInvocationContextInitializer: SmokeServerPerInvocationContextInitializerV2
    where SelectorType ==
    StandardSmokeHTTP1HandlerSelector<ContextType, JSONPayloadHTTP1OperationDelegate<SmokeInvocationTraceContext>,
        OperationIdentifer> {
    associatedtype ContextType
    associatedtype OperationIdentifer

    typealias OperationsInitializerType =
        (inout StandardSmokeHTTP1HandlerSelector<ContextType, JSONPayloadHTTP1OperationDelegate<SmokeInvocationTraceContext>, OperationIdentifer>) -> Void
}

public extension StandardJSONSmokeServerPerInvocationContextInitializer {
    var handlerSelectorProvider: () -> SelectorType {
        func provider() -> SelectorType {
            return SelectorType(defaultOperationDelegate: self.defaultOperationDelegate,
                                serverName: self.serverName,
                                reportingConfiguration: self.reportingConfiguration)
        }

        return provider
    }

    var defaultOperationDelegate: SelectorType.DefaultOperationDelegateType {
        return JSONPayloadHTTP1OperationDelegate()
    }
}
