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
//  SmokeServerReportingConfiguration.swift
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

public struct SmokeServerReportingConfiguration<OperationIdentifer: OperationIdentity> {
    
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
    }
    
    private let successCounterMatchingRequests: MatchingRequests
    private let failure5XXCounterMatchingRequests: MatchingRequests
    private let failure4XXCounterMatchingRequests: MatchingRequests
    private let latencyTimerMatchingRequests: MatchingRequests
    
    public init(successCounterMatchingRequests: MatchingRequests,
                failure5XXCounterMatchingRequests: MatchingRequests,
                failure4XXCounterMatchingRequests: MatchingRequests,
                latencyTimerMatchingRequests: MatchingRequests) {
        self.successCounterMatchingRequests = successCounterMatchingRequests
        self.failure5XXCounterMatchingRequests = failure5XXCounterMatchingRequests
        self.failure4XXCounterMatchingRequests = failure4XXCounterMatchingRequests
        self.latencyTimerMatchingRequests = latencyTimerMatchingRequests
    }
    
    public init(matchingRequests: MatchingRequests = MatchingRequests()) {
        self.successCounterMatchingRequests = matchingRequests
        self.failure5XXCounterMatchingRequests = matchingRequests
        self.failure4XXCounterMatchingRequests = matchingRequests
        self.latencyTimerMatchingRequests = matchingRequests
    }
    
    public func reportSuccessForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return isMatchingRequest(request, matchingRequests: successCounterMatchingRequests)
    }
    
    public func reportFailure5XXForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return isMatchingRequest(request, matchingRequests: failure5XXCounterMatchingRequests)
    }
    
    public func reportFailure4XXForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return isMatchingRequest(request, matchingRequests: failure4XXCounterMatchingRequests)
    }
    
    public func reportLatencyForRequest(_ request: RequestType<OperationIdentifer>) -> Bool {
        return isMatchingRequest(request, matchingRequests: latencyTimerMatchingRequests)
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
