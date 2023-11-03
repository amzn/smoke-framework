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
// StandardSmokeAsyncServerStaticContextInitializer.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeHTTP1
import SmokeOperations
import SmokeOperationsHTTP1

/**
  A protocol that is derived from `SmokeAsyncServerStaticContextInitializer` that uses the `StandardSmokeHTTP1HandlerSelector`
  type as the `SelectorType` and `JSONPayloadHTTP1OperationDelegate` as the `DefaultOperationDelegateType`.

  This reduces the configuration required for applications that use these standard components.
 */
public protocol StandardJSONSmokeAsyncServerStaticContextInitializer: SmokeAsyncServerStaticContextInitializer
    where SelectorType ==
    StandardSmokeHTTP1HandlerSelector<ContextType, JSONPayloadHTTP1OperationDelegate<SmokeInvocationTraceContext>,
        OperationIdentifer> {
    associatedtype ContextType
    associatedtype OperationIdentifer

    typealias OperationsInitializerType =
        (inout StandardSmokeHTTP1HandlerSelector<ContextType, JSONPayloadHTTP1OperationDelegate<SmokeInvocationTraceContext>, OperationIdentifer>) -> Void
}

public extension StandardJSONSmokeAsyncServerStaticContextInitializer {
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

/**
  A protocol that is derived from `SmokeAsyncServerStaticContextInitializerV2` that uses the `StandardSmokeHTTP1HandlerSelector`
  type as the `SelectorType` and `JSONPayloadHTTP1OperationDelegate` as the `DefaultOperationDelegateType`.

  This reduces the configuration required for applications that use these standard components.
 */
public protocol StandardJSONSmokeAsyncServerStaticContextInitializerV3: SmokeAsyncServerStaticContextInitializerV3
    where SelectorType ==
    StandardSmokeHTTP1HandlerSelector<ContextType, JSONPayloadHTTP1HBOperationDelegate<SmokeInvocationTraceContext>,
        OperationIdentifer> {
    associatedtype ContextType
    associatedtype OperationIdentifer

    typealias OperationsInitializerType =
        (inout StandardSmokeHTTP1HandlerSelector<ContextType, JSONPayloadHTTP1HBOperationDelegate<SmokeInvocationTraceContext>, OperationIdentifer>) -> Void
}

public extension StandardJSONSmokeAsyncServerStaticContextInitializerV3 {
    var handlerSelectorProvider: (SmokeReportingConfiguration<SelectorType.OperationIdentifer>) -> SelectorType {
        func provider(reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>) -> SelectorType {
            return SelectorType(defaultOperationDelegate: self.defaultOperationDelegate,
                                serverName: self.serverName,
                                reportingConfiguration: reportingConfiguration)
        }

        return provider
    }

    var defaultOperationDelegate: SelectorType.DefaultOperationDelegateType {
        return JSONPayloadHTTP1HBOperationDelegate(responseExecutor: .existingThread)
    }
}
