// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeOperationsHTTP1

import Foundation
import SmokeHTTP1
import SmokeOperations
import Logging
import NIOHTTP1

extension SmokeServerInvocationContext: HTTP1RequestInvocationContext where
        TraceContextType.RequestHeadType == HTTPRequestHead,
        TraceContextType.ResponseHeadersType == HTTPHeaders, TraceContextType.ResponseStatusType == HTTPResponseStatus {
    
    public var logger: Logger {
        return self.invocationReporting.logger
    }
    
    public func handleInwardsRequestComplete(httpHeaders: inout HTTPHeaders, status: HTTPResponseStatus, body: (contentType: String, data: Data)?) {
        self.invocationReporting.traceContext.handleInwardsRequestComplete(httpHeaders: &httpHeaders, status: status, body: body,
                                                                           logger: self.invocationReporting.logger,
                                                                           internalRequestId: self.invocationReporting.internalRequestId)
    }
}
