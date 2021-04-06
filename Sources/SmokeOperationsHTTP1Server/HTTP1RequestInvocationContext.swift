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
//  HTTP1RequestInvocationContext.swift
//  SmokeOperationsHTTP1Server
//

import Foundation
import Logging
import NIOHTTP1
import Metrics

public protocol HTTP1RequestInvocationContext {
    
    var logger: Logger { get }
    
    var successCounter: Metrics.Counter? { get }
    var failure5XXCounter: Metrics.Counter? { get }
    var failure4XXCounter: Metrics.Counter? { get }
    var latencyTimer: Metrics.Timer? { get }
    var serviceLatencyTimer: Metrics.Timer? { get }
    var outwardsServiceCallLatencySumTimer: Metrics.Timer? { get }
    var outwardsServiceCallRetryWaitSumTimer: Metrics.Timer? { get }
    
    func handleInwardsRequestComplete(httpHeaders: inout HTTPHeaders, status: HTTPResponseStatus,
                                      body: (contentType: String, data: Data)?)
}

public extension HTTP1RequestInvocationContext {
    // The properties is being added as a non-breaking change, so add a default implementation.
    var successCounter: Metrics.Counter? {
        return nil
    }
    
    var failure5XXCounter: Metrics.Counter? {
        return nil
    }
    
    var failure4XXCounter: Metrics.Counter? {
        return nil
    }
    
    var latencyTimer: Metrics.Timer? {
        return nil
    }
    
    var serviceLatencyTimer: Metrics.Timer? {
        return nil
    }
    
    var outwardsServiceCallLatencySumTimer: Metrics.Timer? {
        return nil
    }
    
    var outwardsServiceCallRetryWaitSumTimer: Metrics.Timer? {
        return nil
    }
}
