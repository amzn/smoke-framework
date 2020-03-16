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
//  OperationHTTP1InputProtocol.swift
//  SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations

/**
 A protocol that represents the input to an operation from a HTTP request.
 */
public protocol OperationHTTP1InputProtocol {
    associatedtype QueryType: Decodable
    associatedtype PathType: Decodable
    associatedtype BodyType: Decodable
    associatedtype HeadersType: Decodable
    
    /**
     Composes an instance from its constituent Decodable parts.
     May return one of its constituent parts if of a compatible type.
 
     - Parameters:
        - queryDecodableProvider: provider for the decoded query for this instance.
        - pathDecodableProvider: provider for the decoded http path for this instance.
        - bodyDecodableProvider: provider for the decoded body for this instance.
        - headersDecodableProvider: provider for the decoded headers for this instance.
     */
    static func compose(queryDecodableProvider: () throws -> QueryType,
                        pathDecodableProvider: () throws -> PathType,
                        bodyDecodableProvider: () throws -> BodyType,
                        headersDecodableProvider: () throws -> HeadersType) throws -> Self
}

public typealias ValidatableOperationHTTP1InputProtocol = Validatable & OperationHTTP1InputProtocol
