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
// SmokeAsyncServerStaticContextInitializer.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeOperationsHTTP1

public protocol SmokeAsyncServerPerInvocationContextInitializer {
    associatedtype MiddlewareStackType: ServerMiddlewareStackProtocol
    
    typealias MiddlewareContext = MiddlewareStackType.RouterType.OuterMiddlewareContext
    typealias OperationIdentifer = MiddlewareStackType.RouterType.OperationIdentifer
    typealias ContextType = MiddlewareStackType.ApplicationContextType
    
    var serverName: String { get }
    var serverConfiguration: SmokeServerConfiguration<OperationIdentifer> { get }
    
    var operationsInitializer: ((inout MiddlewareStackType) -> Void) { get }

    @Sendable func getInvocationContext(requestContext: HTTPServerRequestContext<OperationIdentifer>) -> MiddlewareStackType.ApplicationContextType
    
    func onShutdown() async throws
}
