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
// SmokeInwardsRequestContext.swift
// SmokeHTTP1
//

import Foundation
import SmokeHTTPClient

public protocol SmokeInwardsRequestContext {
    var requestStart: Date { get }
    
    var retriableOutputRequestRecords: [RetriableOutputRequestRecord] { get }
    
    var retryAttemptRecords: [RetryAttemptRecord] { get }
}

internal class StandardSmokeInwardsRequestContext: SmokeInwardsRequestContext, OutwardsRequestAggregator {
    let requestStart: Date
    private(set) var retriableOutputRequestRecords: [RetriableOutputRequestRecord]
    private(set) var retryAttemptRecords: [RetryAttemptRecord]
    
    init(requestStart: Date) {
        self.requestStart = requestStart
        self.retriableOutputRequestRecords = []
        self.retryAttemptRecords = []
    }
    
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord) {
        let retriableOutwardsRequest = SmokeRetriableOutputRequestRecord(outputRequests: [outputRequestRecord])
        
        self.retriableOutputRequestRecords.append(retriableOutwardsRequest)
    }
    
    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord) {
        self.retryAttemptRecords.append(retryAttemptRecord)
    }
    
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord) {
        self.retriableOutputRequestRecords.append(retriableOutwardsRequest)
    }
}

struct SmokeRetriableOutputRequestRecord: RetriableOutputRequestRecord {
    var outputRequests: [OutputRequestRecord]
}
