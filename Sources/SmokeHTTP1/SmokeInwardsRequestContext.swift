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
// SmokeInwardsRequestContext.swift
// SmokeHTTP1
//

import Foundation
import SmokeHTTPClient

public protocol SmokeInwardsRequestContext {
    var headReceiveDate: Date? { get }

    var requestStart: Date { get }

    var retriableOutputRequestRecords: [RetriableOutputRequestRecord] { get }

    var retryAttemptRecords: [RetryAttemptRecord] { get }
}

public extension SmokeInwardsRequestContext {
    var headReceiveDate: Date? {
        return nil
    }
}

internal class StandardSmokeInwardsRequestContext: SmokeInwardsRequestContext, OutwardsRequestAggregator {
    let headReceiveDate: Date?
    let requestStart: Date
    private(set) var retriableOutputRequestRecords: [RetriableOutputRequestRecord]
    private(set) var retryAttemptRecords: [RetryAttemptRecord]

    internal let accessQueue = DispatchQueue(
        label: "com.amazon.SmokeFramework.StandardSmokeInwardsRequestContext.accessQueue",
        target: DispatchQueue.global())

    init(headReceiveDate: Date?, requestStart: Date) {
        self.headReceiveDate = headReceiveDate
        self.requestStart = requestStart
        self.retriableOutputRequestRecords = []
        self.retryAttemptRecords = []
    }

    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord, onCompletion: @escaping () -> Void) {
        self.accessQueue.async {
            let retriableOutwardsRequest = SmokeRetriableOutputRequestRecord(outputRequests: [outputRequestRecord])

            self.retriableOutputRequestRecords.append(retriableOutwardsRequest)

            onCompletion()
        }
    }

    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord, onCompletion: @escaping () -> Void) {
        self.accessQueue.async {
            self.retryAttemptRecords.append(retryAttemptRecord)

            onCompletion()
        }
    }

    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord, onCompletion: @escaping () -> Void) {
        self.accessQueue.async {
            self.retriableOutputRequestRecords.append(retriableOutwardsRequest)

            onCompletion()
        }
    }

    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord) {
        let retriableOutwardsRequest = SmokeRetriableOutputRequestRecord(outputRequests: [outputRequestRecord])

        self.retriableOutputRequestRecords.append(retriableOutwardsRequest)
    }

    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord) {
        self.retryAttemptRecords.append(retryAttemptRecord)
    }

    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord) {
        self.retriableOutputRequestRecords.append(retriableOutwardsRequest)
    }
}

struct SmokeRetriableOutputRequestRecord: RetriableOutputRequestRecord {
    var outputRequests: [OutputRequestRecord]
}
