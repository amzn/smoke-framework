// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// ExampleOutput.swift
// SmokeAPI
//

import Foundation
import SmokeOperations

enum BodyColor: String, Codable {
    case yellow = "YELLOW"
    case blue = "BLUE"
}

struct ExampleOutput: Codable, Validatable {
    let bodyColor: BodyColor
    let isGreat: Bool
    
    func validate() throws {
        if case .yellow = bodyColor {
            throw SmokeOperationsError.validationError(reason: "The body color is yellow.")
        }
    }
}

extension ExampleOutput : Equatable {
    static func ==(lhs: ExampleOutput, rhs: ExampleOutput) -> Bool {
        return lhs.bodyColor == rhs.bodyColor
            && lhs.isGreat == rhs.isGreat
    }
}
