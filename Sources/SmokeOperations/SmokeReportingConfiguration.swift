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
//  SmokeReportingConfiguration.swift
//  SmokeOperations
//

import Foundation

public enum RequestType<OperationIdentifer: OperationIdentity>: CustomStringConvertible {
    case serverOperation(OperationIdentifer)
    case ping
    case unknownOperation
    case errorDeterminingOperation

    public var description: String {
        switch self {
            case .ping:
                return "Ping"
            case .serverOperation(let operation):
                return operation.description
            case .unknownOperation:
                return "UnknownOperation"
            case .errorDeterminingOperation:
                return "ErrorDeterminingOperation"
        }
    }
}

public struct SmokeReportingConfiguration<OperationIdentifer: OperationIdentity> {
    // TODO: Remove non-inclusive language
    // https://github.com/amzn/smoke-framework/issues/74
    public enum MatchingOperations {
        case all
        case whitelist(Set<OperationIdentifer>)
        case blacklist(Set<OperationIdentifer>)
        case none
    }

    public struct MatchingRequests {
        public let ping: Bool
        public let unknownOperation: Bool
        public let errorDeterminingOperation: Bool
        public let matchingOperations: MatchingOperations

        public init(ping: Bool = false, unknownOperation: Bool = true, errorDeterminingOperation: Bool = true,
                    matchingOperations: MatchingOperations = .all) {
            self.ping = ping
            self.unknownOperation = unknownOperation
            self.errorDeterminingOperation = errorDeterminingOperation
            self.matchingOperations = matchingOperations
        }

        public static var all: MatchingRequests {
            return .init(matchingOperations: .all)
        }

        public static var none: MatchingRequests {
            return .init(matchingOperations: .none)
        }

        public static func onlyForOperations(_ operations: Set<OperationIdentifer>) -> MatchingRequests {
            return .init(matchingOperations: .whitelist(operations))
        }

        public static func exceptForOperations(_ operations: Set<OperationIdentifer>) -> MatchingRequests {
            return .init(matchingOperations: .blacklist(operations))
        }
    }

    public let specificFailureStatusesToReport: Set<UInt>?

    private let successCounterMatchingRequests: MatchingRequests
    private let failure5XXCounterMatchingRequests: MatchingRequests
    private let failure4XXCounterMatchingRequests: MatchingRequests
    private let requestReadLatencyTimerMatchingRequests: MatchingRequests
    private let specificFailureStatusCounterMatchingRequests: MatchingRequests
    private let latencyTimerMatchingRequests: MatchingRequests

    // these are added as a non-breaking change, so by default they are not enabled
    private let serviceLatencyTimerMatchingRequests: MatchingRequests
    private let outwardServiceCallLatencySumTimerMatchingRequests: MatchingRequests
    private let outwardServiceCallRetryWaitSumTimerMatchingRequests: MatchingRequests

    public init(successCounterMatchingRequests: MatchingRequests,
                failure5XXCounterMatchingRequests: MatchingRequests,
                failure4XXCounterMatchingRequests: MatchingRequests,
                requestReadLatencyTimerMatchingRequests: MatchingRequests = .none,
                latencyTimerMatchingRequests: MatchingRequests,
                serviceLatencyTimerMatchingRequests: MatchingRequests = .none,
                outwardServiceCallLatencyTimerMatchingRequests: MatchingRequests = .none,
                outwardServiceCallRetryWaitTimerMatchingRequests: MatchingRequests = .none) {
        self.successCounterMatchingRequests = successCounterMatchingRequests
        self.failure5XXCounterMatchingRequests = failure5XXCounterMatchingRequests
        self.failure4XXCounterMatchingRequests = failure4XXCounterMatchingRequests
        self.requestReadLatencyTimerMatchingRequests = requestReadLatencyTimerMatchingRequests
        self.latencyTimerMatchingRequests = latencyTimerMatchingRequests
        self.serviceLatencyTimerMatchingRequests = serviceLatencyTimerMatchingRequests
        self.outwardServiceCallLatencySumTimerMatchingRequests = outwardServiceCallLatencyTimerMatchingRequests
        self.outwardServiceCallRetryWaitSumTimerMatchingRequests = outwardServiceCallRetryWaitTimerMatchingRequests
        self.specificFailureStatusCounterMatchingRequests = .none
        self.specificFailureStatusesToReport = nil
    }

    public init(successCounterMatchingRequests: MatchingRequests,
                failure5XXCounterMatchingRequests: MatchingRequests,
                failure4XXCounterMatchingRequests: MatchingRequests,
                specificFailureStatusCounterMatchingRequests: MatchingRequests,
                specificFailureStatusesToReport: Set<UInt>,
                requestReadLatencyTimerMatchingRequests: MatchingRequests = .none,
                latencyTimerMatchingRequests: MatchingRequests,
                serviceLatencyTimerMatchingRequests: MatchingRequests = .none,
                outwardServiceCallLatencyTimerMatchingRequests: MatchingRequests = .none,
                outwardServiceCallRetryWaitTimerMatchingRequests: MatchingRequests = .none) {
        self.successCounterMatchingRequests = successCounterMatchingRequests
        self.failure5XXCounterMatchingRequests = failure5XXCounterMatchingRequests
        self.failure4XXCounterMatchingRequests = failure4XXCounterMatchingRequests
        self.requestReadLatencyTimerMatchingRequests = requestReadLatencyTimerMatchingRequests
        self.latencyTimerMatchingRequests = latencyTimerMatchingRequests
        self.serviceLatencyTimerMatchingRequests = serviceLatencyTimerMatchingRequests
        self.outwardServiceCallLatencySumTimerMatchingRequests = outwardServiceCallLatencyTimerMatchingRequests
        self.outwardServiceCallRetryWaitSumTimerMatchingRequests = outwardServiceCallRetryWaitTimerMatchingRequests
        self.specificFailureStatusCounterMatchingRequests = specificFailureStatusCounterMatchingRequests
        self.specificFailureStatusesToReport = specificFailureStatusesToReport
    }

    // Metrics added within the current major version are set to .none
    // to maintain existing behaviour
    public init(matchingRequests: MatchingRequests = MatchingRequests()) {
        self.successCounterMatchingRequests = matchingRequests
        self.failure5XXCounterMatchingRequests = matchingRequests
        self.failure4XXCounterMatchingRequests = matchingRequests
        self.requestReadLatencyTimerMatchingRequests = .none
        self.latencyTimerMatchingRequests = matchingRequests
        self.serviceLatencyTimerMatchingRequests = .none
        self.outwardServiceCallLatencySumTimerMatchingRequests = .none
        self.outwardServiceCallRetryWaitSumTimerMatchingRequests = .none
        self.specificFailureStatusCounterMatchingRequests = .none
        self.specificFailureStatusesToReport = nil
    }

    public func reportSuccessForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.successCounterMatchingRequests)
    }

    public func reportFailure5XXForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.failure5XXCounterMatchingRequests)
    }

    public func reportFailure4XXForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.failure4XXCounterMatchingRequests)
    }

    public func reportRequestReadLatencyForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.requestReadLatencyTimerMatchingRequests)
    }

    public func reportSpecificFailureStatusesForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.specificFailureStatusCounterMatchingRequests)
    }

    public func reportLatencyForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.latencyTimerMatchingRequests)
    }

    public func reportServiceLatencyForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.serviceLatencyTimerMatchingRequests)
    }

    public func reportOutwardsServiceCallLatencySumForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.outwardServiceCallLatencySumTimerMatchingRequests)
    }

    public func reportOutwardsServiceCallRetryWaitLatencySumForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return self.isMatchingRequest(request, matchingRequests: self.outwardServiceCallRetryWaitSumTimerMatchingRequests)
    }

    private func isMatchingRequest(_ request: RequestType<OperationIdentifer>, matchingRequests: MatchingRequests) -> Bool {
        switch request {
            case .ping:
                return matchingRequests.ping
            case .serverOperation(let operation):
                switch matchingRequests.matchingOperations {
                    case .all:
                        return true
                    case .whitelist(let whitelist):
                        return whitelist.contains(operation)
                    case .blacklist(let blacklist):
                        return !blacklist.contains(operation)
                    case .none:
                        return false
                }
            case .unknownOperation:
                return matchingRequests.unknownOperation
            case .errorDeterminingOperation:
                return matchingRequests.errorDeterminingOperation
        }
    }
}
