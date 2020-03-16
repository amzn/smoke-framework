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
// ErrorWithTypeTests.swift
// SmokeOperations
//

import XCTest
@testable import SmokeOperations

struct ExampleErrorShape: Encodable {
    let message: String
}

struct ExpectedShape: Codable {
    let message: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case type = "__type"
    }
}

extension ExpectedShape: Equatable {
    static func ==(lhs: ExpectedShape, rhs: ExpectedShape) -> Bool {
        return lhs.message == rhs.message && lhs.type == rhs.type
    }
}

class ErrorWithTypeTests: XCTestCase {

    func testEncoding() {
        let errorShape = ExampleErrorShape(message: "The message")
        let errorWithType = ErrorWithType(type: "BadError", payload: errorShape)
        
        let encodedData = try! JSONEncoder.getFrameworkEncoder().encode(errorWithType)
        let recovered = try! JSONDecoder.getFrameworkDecoder().decode(ExpectedShape.self, from: encodedData)
        
        let expected = ExpectedShape(message: "The message", type: "BadError")
        
        XCTAssertEqual(expected, recovered)
    }

    static var allTests = [
        ("testEncoding", testEncoding),
    ]
}
