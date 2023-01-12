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
//  SmokeOperationReporting.swift
//  SmokeOperations
//
import Foundation
import Logging
import Metrics

private let namespaceDimension = "Namespace"
private let operationNameDimension = "Operation Name"
private let metricNameDimension = "Metric Name"

private let successCountMetric = "successCount"
private let failure5XXCountMetric = "failure5XXCount"
private let failure4XXCountMetric = "failure4XXCount"
private let specificFailureStatusCountMetricFormat = "failure%dCount"
private let latencyTimeMetric = "latencyTime"
private let serviceLatencyTimeMetric = "serviceLatencyTime"
private let outwardsServiceCallLatencySumMetric = "outwardsServiceCallLatencySum"
private let outwardsServiceCallRetryWaitSumMetric = "outwardsServiceCallRetryWaitSum"

/**
  Stores the counters for reporting on a particular operation.
 */
public struct SmokeOperationReporting {
    public let successCounter: Metrics.Counter?
    public let failure5XXCounter: Metrics.Counter?
    public let failure4XXCounter: Metrics.Counter?
    public let specificFailureStatusCounters: [UInt: Metrics.Counter]?
    public let latencyTimer: Metrics.Timer?
    public let serviceLatencyTimer: Metrics.Timer?
    public let outwardsServiceCallLatencySumTimer: Metrics.Timer?
    public let outwardsServiceCallRetryWaitSumTimer: Metrics.Timer?
    
    public init<OperationIdentifer: OperationIdentity>(serverName: String, request: RequestType<OperationIdentifer>,
                                                       configuration: SmokeReportingConfiguration<OperationIdentifer>) {
        let operationName = request.description
        
        func getCounter(metricName: String) -> Counter {
            let counterDimensions = [(namespaceDimension, serverName),
                                     (operationNameDimension, operationName),
                                     (metricNameDimension, metricName)]
            return Counter(label: "\(serverName).\(operationName).\(metricName)",
                           dimensions: counterDimensions)
        }
        
        func getTimer(metricName: String) -> Timer {
            let timerDimensions = [(namespaceDimension, serverName),
                                   (operationNameDimension, operationName),
                                   (metricNameDimension, metricName)]
            return Timer(label: "\(serverName).\(operationName).\(metricName)",
                         dimensions: timerDimensions)
        }
        
        if configuration.reportSuccessForRequest(request) {
            successCounter = getCounter(metricName: successCountMetric)
        } else {
            successCounter = nil
        }
        
        if configuration.reportFailure5XXForRequest(request) {
            failure5XXCounter = getCounter(metricName: failure5XXCountMetric)
        } else {
            failure5XXCounter = nil
        }
        
        if configuration.reportFailure4XXForRequest(request) {
            failure4XXCounter = getCounter(metricName: failure4XXCountMetric)
        } else {
            failure4XXCounter = nil
        }
        
        if configuration.reportSpecificFailureStatusesForRequest(request),
           let specificFailureStatusesToReport = configuration.specificFailureStatusesToReport {
            let countersWithStatusCodes: [(UInt, Counter)] = specificFailureStatusesToReport.map { statusCode in
                let metricName = String(format: specificFailureStatusCountMetricFormat, statusCode)
                let specificFailureStatusCounter = getCounter(metricName: metricName)
                return (statusCode, specificFailureStatusCounter)
            }
            specificFailureStatusCounters = Dictionary(uniqueKeysWithValues: countersWithStatusCodes)
        } else {
            specificFailureStatusCounters = nil
        }
        
        if configuration.reportLatencyForRequest(request) {
            latencyTimer = getTimer(metricName: latencyTimeMetric)
        } else {
            latencyTimer = nil
        }
        
        if configuration.reportServiceLatencyForRequest(request) {
            serviceLatencyTimer = getTimer(metricName: serviceLatencyTimeMetric)
        } else {
            serviceLatencyTimer = nil
        }
        
        if configuration.reportOutwardsServiceCallLatencySumForRequest(request) {
            outwardsServiceCallLatencySumTimer = getTimer(metricName: outwardsServiceCallLatencySumMetric)
        } else {
            outwardsServiceCallLatencySumTimer = nil
        }
        
        if configuration.reportOutwardsServiceCallRetryWaitLatencySumForRequest(request) {
            outwardsServiceCallRetryWaitSumTimer = getTimer(metricName: outwardsServiceCallRetryWaitSumMetric)
        } else {
            outwardsServiceCallRetryWaitSumTimer = nil
        }
    }
}
