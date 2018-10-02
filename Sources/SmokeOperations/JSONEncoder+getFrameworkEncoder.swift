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
// JSONEncoder+getFrameworkEncoder.swift
// SwiftOperations
//

import Foundation
import LoggerAPI

private func createEncoder() -> JSONEncoder {
    let jsonEncoder = JSONEncoder()
    if #available(OSX 10.12, *) {
        jsonEncoder.dateEncodingStrategy = .iso8601
    }

    jsonEncoder.outputFormatting = .prettyPrinted
    
    return jsonEncoder
}

private let jsonEncoder = createEncoder()

// swiftlint:disable force_try
// If all else fails, an error payload to use.
private let encodedInternalError = try! jsonEncoder.encode(
    ErrorWithType(type: "InternalError",
                  payload: SmokeOperationsErrorPayload(errorMessage: nil)))
// swiftlint:enable force_try

extension JSONEncoder {
    /// Return a SmokeFramework compatible JSON Encoder
    static func getFrameworkEncoder() -> JSONEncoder {
        return jsonEncoder
    }
    
    /**
     Encodes a payload for use as a response, optionally with a reason.
 
     - Parameters:
        - payload: The payload to encode.
        - reason: Optionally the reason to include in the payload.
     */
    public static func encodePayload<EncodableType: Encodable>(
        payload: EncodableType,
        reason: String? = nil) -> Data {
            let encodedError: Data
            
            do {
                if let reason = reason {
                    let errorWithReason = ErrorWithType(type: reason,
                                                        payload: payload)
                    encodedError = try jsonEncoder.encode(errorWithReason)
                } else {
                    encodedError = try jsonEncoder.encode(payload)
                }
            } catch {
                Log.error("Unable to encode error message: \(error)")
                
                encodedError = encodedInternalError
            }
            
            return encodedError
    }
}
