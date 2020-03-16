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
//  PathOperationHTTPInput.swift
//  SmokeOperationsHTTP1
//

import Foundation

/**
 Implementation of the OperationHTTP1InputProtocol that only decodes
 the HTTP path.
 */
public struct PathOperationHTTPInput<PathType: Decodable>: OperationHTTP1InputProtocol {
    // This struct doesn't use these types but we must provide a
    // concrete type to satify the protocol
    public typealias QueryType = String
    public typealias BodyType = String
    public typealias HeadersType = String
    
    public let path: PathType
    
    public init(path: PathType) {
        self.path = path
    }
    
    public static func compose(queryDecodableProvider: () throws -> String,
                               pathDecodableProvider: () throws -> PathType,
                               bodyDecodableProvider: () throws -> String,
                               headersDecodableProvider: () throws -> String) throws -> PathOperationHTTPInput {
        let path = try pathDecodableProvider()
        
        return .init(path: path)
    }
}
