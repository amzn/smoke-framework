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
// TestConfiguration.swift
// SmokeOperationsTests
//

import Foundation
@testable import SmokeOperations
import NIOHTTP1
import SmokeHTTP1

struct ExampleContext {
}

let serializedInput = """
    {
      "theID" : "123456789012"
    }
    """

let serializedAlternateInput = """
    {
      "theID" : "888888888888"
    }
    """

let serializedInvalidInput = """
    {
      "theID" : "1789012"
    }
    """

struct OperationResponse {
    let status: HTTPResponseStatus
    let body: (contentType: String, data: Data)?
}

class TestHttpResponseHandler: HTTP1ResponseHandler {
    var response: OperationResponse?
    
    func complete(status: HTTPResponseStatus,
                  body: (contentType: String, data: Data)?) {
        response = OperationResponse(status: status,
                                    body: body)
    }
}

public enum MyError: Swift.Error {
    case theError(reason: String)
    
    enum CodingKeys: String, CodingKey {
        case reason = "Reason"
    }
}

extension MyError: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .theError(reason: let reason):
            try container.encode(reason, forKey: .reason)
        }
    }
}

extension MyError: CustomStringConvertible {
    public var description: String {
        return "TheError"
    }
}

let allowedErrors = [(MyError.theError(reason: "MyError"), 400)]

struct ErrorResponse: Codable {
    let type: String
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case type = "__type"
        case reason = "Reason"
    }
}

struct ExampleInput: Codable, Validatable {
    let theID: String
    
    func validate() throws {
        if theID.count != 12 {
            throw SmokeOperationsError.validationError(reason: "ID not the correct length.")
        }
    }
}

extension ExampleInput : Equatable {
    static func ==(lhs: ExampleInput, rhs: ExampleInput) -> Bool {
        return lhs.theID == rhs.theID
    }
}

enum BodyColor: String, Codable {
    case yellow = "YELLOW"
    case blue = "BLUE"
}

struct OutputAttributes: Codable, Validatable {
    let bodyColor: BodyColor
    let isGreat: Bool
    
    func validate() throws {
        if case .yellow = bodyColor {
            throw SmokeOperationsError.validationError(reason: "The body color is yellow.")
        }
    }
}

extension OutputAttributes : Equatable {
    static func ==(lhs: OutputAttributes, rhs: OutputAttributes) -> Bool {
        return lhs.bodyColor == rhs.bodyColor
            && lhs.isGreat == rhs.isGreat
    }
}
