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
// SmokeAsyncPerInvocationContextInitializer.swift
// SmokeOperationsHTTP1
//

import NIO
import SmokeOperations
import Logging

/**
  A protocol for initialization SmokeFramework-based applications that require a per-invocation context.
 
  This initializer supports async shutdown.
 */
public protocol SmokeAsyncPerInvocationContextInitializer {
    associatedtype MiddlewareStackType: ServerMiddlewareStackProtocol
    typealias OperationIdentifer = MiddlewareStackType.RouterType.OperationIdentifer
    
    var middlewareStackProvider: (() -> MiddlewareStackType) { get }
    var operationsInitializer: ((inout MiddlewareStackType) -> Void) { get }

    func getInvocationContext(requestContext: HTTPServerRequestContext<OperationIdentifer>) -> MiddlewareStackType.ApplicationContextType
    
    func onShutdown() async throws
}

