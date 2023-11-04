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
// GenericSmokeServerConfiguration.swift
// SmokeOperationsHTTP1Server
//

import SmokeHTTP1
import SmokeOperations
import SmokeOperationsHTTP1
import UnixSignals
import NIOCore
import NIOPosix

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
