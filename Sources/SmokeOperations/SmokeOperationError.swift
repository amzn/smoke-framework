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
// SmokeOperationsError.swift
// SmokeOperations
//

import Foundation

/**
 Errors that can thrown as part of the SmokeOperations library.
 */
public enum SmokeOperationsError: Error {
    /// There was an error during validation of input or output.
    case validationError(reason: String)
    /// There was no registered operation for the incoming request.
    case invalidOperation(reason: String)
}

/**
 Error payload shape for SmokeOperationsErrors.
 */
public struct SmokeOperationsErrorPayload: Codable {
    let errorMessage: String?
    
    public init(errorMessage: String?) {
        self.errorMessage = errorMessage
    }
    
    enum CodingKeys: String, CodingKey {
        case errorMessage = "message"
    }
}
