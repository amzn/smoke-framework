// Copyright 2018-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeServerInvocationReporting+withInvocationTraceContext.swift
// SmokeOperationsHTTP1Server

import Foundation
import Logging
import SmokeOperations
import SmokeHTTPClient
import NIO

public struct DelegatedInvocationReporting<TraceContextType: InvocationTraceContext>: HTTPClientCoreInvocationReporting {
    public let logger: Logger
    public var internalRequestId: String
    public var traceContext: TraceContextType
    public var eventLoop: EventLoop?
    public var outwardsRequestAggregator: OutwardsRequestAggregator?
    
    public init(logger: Logger,
                internalRequestId: String,
                traceContext: TraceContextType,
                eventLoop: EventLoop? = nil,
                outwardsRequestAggregator: OutwardsRequestAggregator? = nil) {
        self.logger = logger
        self.internalRequestId = internalRequestId
        self.traceContext = traceContext
        self.eventLoop = eventLoop
        self.outwardsRequestAggregator = outwardsRequestAggregator
    }
}

public extension SmokeServerInvocationReporting {
    
    /**
     * Creates an instance conforming to the `HTTPClientCoreInvocationReporting` protocol from this instance and the provided trace context.
     */
    func withInvocationTraceContext<TraceContextType: InvocationTraceContext>(
        traceContext: TraceContextType) -> DelegatedInvocationReporting<TraceContextType> {
        return DelegatedInvocationReporting(logger: self.logger,
                                            internalRequestId: self.internalRequestId,
                                            traceContext: traceContext,
                                            eventLoop: self.eventLoop,
                                            outwardsRequestAggregator: self.outwardsRequestAggregator)
        
    }
}
