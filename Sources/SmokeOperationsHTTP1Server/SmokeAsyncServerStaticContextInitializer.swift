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
// SmokeServerStaticContextInitializerV2.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeHTTP1
import SmokeOperationsHTTP1
import ServiceLifecycle

public protocol SmokeAsyncServerStaticContextInitializer: SmokeAsyncStaticContextInitializer {
    var port: Int { get }
    var shutdownOnSignals: [SmokeHTTP1Server.ShutdownOnSignal] { get }
    var eventLoopProvider: SmokeHTTP1Server.EventLoopProvider { get }
    var requestExecutor: RequestExecutor { get }
    var enableTracingWithSwiftConcurrency: Bool { get }
}

public extension SmokeAsyncServerStaticContextInitializer {
    var port: Int {
        return ServerDefaults.defaultPort
    }

    var shutdownOnSignals: [SmokeHTTP1Server.ShutdownOnSignal] {
        return [.sigint]
    }

    var eventLoopProvider: SmokeHTTP1Server.EventLoopProvider {
        return .spawnNewThreads
    }

    var requestExecutor: RequestExecutor {
        return .originalEventLoop
    }

    var enableTracingWithSwiftConcurrency: Bool {
        return false
    }
}

public protocol SmokeAsyncServerStaticContextInitializerV2: SmokeAsyncServerStaticContextInitializer {
    /**
     Returns the ordered list of services to be started with the
     runtime and shutdown when the runtime is shutdown.
     The order returned will determine the order the services are started in.
     The provided `smokeService` represents the application being started by the framework, allowing other services
     to be started before or after based on the order of the returned list.
     */
    func getServices(smokeService: any Service) -> [any Service]
}

public extension SmokeAsyncServerStaticContextInitializerV2 {
    func getServices(smokeService: any Service) -> [any Service] {
        return [smokeService]
    }
}
