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
// SmokeServerInvocationContext+HTTP1RequestInvocationContext.swift
// SmokeOperationsHTTP1Server

import Foundation
import SmokeHTTP1
import SmokeOperations
import Logging
import NIOHTTP1
import Metrics

extension SmokeInvocationContext: HTTP1RequestInvocationContext where
        InvocationReportingType: InvocationReportingWithTraceContext,
        InvocationReportingType.TraceContextType.RequestHeadType == HTTPRequestHead,
        InvocationReportingType.TraceContextType.ResponseHeadersType == HTTPHeaders,
    InvocationReportingType.TraceContextType.ResponseStatusType == HTTPResponseStatus {
    
    public var logger: Logger {
        return self.invocationReporting.logger
    }
    
    public var successCounter: Metrics.Counter? {
        return self.requestReporting.successCounter
    }
    
    public var failure5XXCounter: Metrics.Counter? {
        return self.requestReporting.failure5XXCounter
    }
    
    public var failure4XXCounter: Metrics.Counter? {
        return self.requestReporting.failure4XXCounter
    }
    
    public var latencyTimer: Metrics.Timer? {
        return self.requestReporting.latencyTimer
    }
    
    public var serviceLatencyTimer: Metrics.Timer? {
        return self.requestReporting.serviceLatencyTimer
    }
    
    public var outwardsServiceCallLatencySumTimer: Metrics.Timer? {
        return self.requestReporting.outwardsServiceCallLatencySumTimer
    }
    
    public var outwardsServiceCallRetryWaitSumTimer: Metrics.Timer? {
        return self.requestReporting.outwardsServiceCallRetryWaitSumTimer
    }
    
    public func handleInwardsRequestComplete(httpHeaders: inout HTTPHeaders, status: HTTPResponseStatus, body: (contentType: String, data: Data)?) {
        self.invocationReporting.traceContext.handleInwardsRequestComplete(httpHeaders: &httpHeaders, status: status, body: body,
                                                                           logger: self.invocationReporting.logger,
                                                                           internalRequestId: self.invocationReporting.internalRequestId)
    }
}
