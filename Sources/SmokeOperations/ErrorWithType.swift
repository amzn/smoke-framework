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
// ErrorWithReason.swift
// SmokeOperations
//

import Foundation

/**
 A struct for encoding errors that preserves the expected output shape
 of the error response but adds the reason.
 */
struct ErrorWithType<PayloadType: Encodable>: Encodable {
    let type: String
    let payload: PayloadType
    
    enum CodingKeys: String, CodingKey {
        case type = "__type"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        try payload.encode(to: encoder)
    }
}
