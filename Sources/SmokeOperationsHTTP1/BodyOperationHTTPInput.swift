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
//  BodyOperationHTTPInput.swift
//  SmokeOperationsHTTP1
//

import Foundation

/**
 Implementation of the OperationHTTP1InputProtocol that only decodes
 the HTTP body.
 */
public struct BodyOperationHTTPInput<BodyType: Decodable>: OperationHTTP1InputProtocol {
    // This struct doesn't use these types but we must provide a
    // concrete type to satify the protocol
    public typealias QueryType = String
    public typealias PathType = String
    public typealias HeadersType = String
    
    public let body: BodyType
    
    public init(body: BodyType) {
        self.body = body
    }
    
    public static func compose(queryDecodableProvider: () throws -> String,
                               pathDecodableProvider: () throws -> String,
                               bodyDecodableProvider: () throws -> BodyType,
                               headersDecodableProvider: () throws -> String) throws -> BodyOperationHTTPInput {
        let body = try bodyDecodableProvider()
        
        return .init(body: body)
    }
}
