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
        
        if configuration.reportSuccessForRequest(request) {
            let successCounterDimensions = [(namespaceDimension, serverName),
                                            (operationNameDimension, operationName),
                                            (metricNameDimension, successCountMetric)]
            successCounter = Counter(label: "\(serverName).\(operationName).\(successCountMetric)",
                                     dimensions: successCounterDimensions)
        } else {
            successCounter = nil
        }
        
        if configuration.reportFailure5XXForRequest(request) {
            let failure5XXCounterDimensions = [(namespaceDimension, serverName),
                                               (operationNameDimension, operationName),
                                               (metricNameDimension, failure5XXCountMetric)]
            failure5XXCounter = Counter(label: "\(serverName).\(operationName).\(failure5XXCountMetric)",
                                        dimensions: failure5XXCounterDimensions)
        } else {
            failure5XXCounter = nil
        }
        
        if configuration.reportFailure4XXForRequest(request) {
            let failure4XXCounterDimensions = [(namespaceDimension, serverName),
                                               (operationNameDimension, operationName),
                                               (metricNameDimension, failure4XXCountMetric)]
            failure4XXCounter = Counter(label: "\(serverName).\(operationName).\(failure4XXCountMetric)",
                                        dimensions: failure4XXCounterDimensions)
        } else {
            failure4XXCounter = nil
        }
        
        if configuration.reportSpecificFailureStatusesForRequest(request),
           let specificFailureStatusesToReport = configuration.specificFailureStatusesToReport {
            let countersWithStatusCodes: [(UInt, Counter)] = specificFailureStatusesToReport.map { statusCode in
                let metricName = String(format: specificFailureStatusCountMetricFormat, statusCode)
                let specificFailureStatusDimensions = [(namespaceDimension, serverName),
                                                       (operationNameDimension, operationName),
                                                       (metricNameDimension, metricName)]
                let specificFailureStatusCounter = Counter(label: "\(serverName).\(operationName).\(metricName)",
                                                           dimensions: specificFailureStatusDimensions)
                return (statusCode, specificFailureStatusCounter)
            }
            specificFailureStatusCounters = Dictionary(uniqueKeysWithValues: countersWithStatusCodes)
        } else {
            specificFailureStatusCounters = nil
        }
        
        if configuration.reportLatencyForRequest(request) {
            let latencyTimeDimensions = [(namespaceDimension, serverName),
                                         (operationNameDimension, operationName),
                                         (metricNameDimension, latencyTimeMetric)]
            latencyTimer = Metrics.Timer(label: "\(serverName).\(operationName).\(latencyTimeMetric)",
                                         dimensions: latencyTimeDimensions)
        } else {
            latencyTimer = nil
        }
        
        if configuration.reportServiceLatencyForRequest(request) {
            let serviceLatencyTimeDimensions = [(namespaceDimension, serverName),
                                                (operationNameDimension, operationName),
                                                (metricNameDimension, serviceLatencyTimeMetric)]
            serviceLatencyTimer = Metrics.Timer(label: "\(serverName).\(operationName).\(serviceLatencyTimeMetric)",
                                                dimensions: serviceLatencyTimeDimensions)
        } else {
            serviceLatencyTimer = nil
        }
        
        if configuration.reportOutwardsServiceCallLatencySumForRequest(request) {
            let serviceLatencyTimeDimensions = [(namespaceDimension, serverName),
                                                (operationNameDimension, operationName),
                                                (metricNameDimension, outwardsServiceCallLatencySumMetric)]
            outwardsServiceCallLatencySumTimer = Metrics.Timer(label: "\(serverName).\(operationName).\(outwardsServiceCallLatencySumMetric)",
                                                               dimensions: serviceLatencyTimeDimensions)
        } else {
            outwardsServiceCallLatencySumTimer = nil
        }
        
        if configuration.reportOutwardsServiceCallRetryWaitLatencySumForRequest(request) {
            let serviceLatencyTimeDimensions = [(namespaceDimension, serverName),
                                                (operationNameDimension, operationName),
                                                (metricNameDimension, outwardsServiceCallRetryWaitSumMetric)]
            outwardsServiceCallRetryWaitSumTimer = Metrics.Timer(label: "\(serverName).\(operationName).\(outwardsServiceCallRetryWaitSumMetric)",
                                                                 dimensions: serviceLatencyTimeDimensions)
        } else {
            outwardsServiceCallRetryWaitSumTimer = nil
        }
    }
}
