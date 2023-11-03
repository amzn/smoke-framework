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
// SmokeAsyncServerStaticContextInitializer.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import ServiceLifecycle
import SmokeHTTP1
import SmokeOperations
import SmokeOperationsHTTP1
import UnixSignals
import NIOCore
import NIOPosix

public protocol SmokeAsyncServerPerInvocationContextInitializer: SmokeAsyncPerInvocationContextInitializer {
    var port: Int { get }
    var shutdownOnSignals: [SmokeHTTP1Server.ShutdownOnSignal] { get }
    var eventLoopProvider: SmokeHTTP1Server.EventLoopProvider { get }
    var requestExecutor: RequestExecutor { get }
    var enableTracingWithSwiftConcurrency: Bool { get }
}

public extension SmokeAsyncServerPerInvocationContextInitializer {
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

public struct GenericSmokeServerConfiguration<SelectorType: SmokeHTTP1HandlerSelector> {
    public var port: Int
    public var shutdownOnSignals: [UnixSignal]
    public var eventLoopGroup: EventLoopGroup
    public var enableTracingWithSwiftConcurrency: Bool
    public var reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>
        
    public init(port: Int = ServerDefaults.defaultPort,
                shutdownOnSignals: [UnixSignal] = [.sigint, .sigterm],
                eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup.singleton,
                enableTracingWithSwiftConcurrency: Bool = true,
                reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer> = .init()) {
        self.port = port
        self.shutdownOnSignals = shutdownOnSignals
        self.eventLoopGroup = eventLoopGroup
        self.enableTracingWithSwiftConcurrency = enableTracingWithSwiftConcurrency
        self.reportingConfiguration = reportingConfiguration
    }
}

public protocol SmokeAsyncServerPerInvocationContextInitializerV3: SmokeAsyncPerInvocationContextInitializerV3 {
    typealias SmokeServerConfiguration = GenericSmokeServerConfiguration<SelectorType>
    
    /**
     Returns the ordered list of services to be started with the
     runtime and shutdown when the runtime is shutdown.
     The order returned will determine the order the services are started in.
     The provided `smokeService` represents the application being started by the framework, allowing other services
     to be started before or after based on the order of the returned list.
     */
    func getServices(smokeService: any Service) -> [any Service]
}

public extension SmokeAsyncServerPerInvocationContextInitializerV3 {
    func getServices(smokeService: any Service) -> [any Service] {
        return [smokeService]
    }
}
