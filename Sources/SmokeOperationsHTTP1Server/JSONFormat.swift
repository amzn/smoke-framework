// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  JSONFormat.swift
//  SmokeOperationsHTTP1Server
//

import Foundation
import Logging
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations

internal struct MimeTypes {
    static let json = "application/json"
}

internal struct JSONFormat {
    static func writeErrorResponse(reason: String, errorMessage: String?,
                                   status: HTTPResponseStatus, logger: Logger?,
                                   responseWriter: any HTTPServerResponseWriterProtocol) async throws {
        let errorResult = SmokeOperationsErrorPayload(errorMessage: errorMessage)
        let encodedError = JSONEncoder.encodePayload(payload: errorResult, logger: logger,
                                                     reason: reason)
        
        await responseWriter.setStatus(status)
        await responseWriter.setContentType(MimeTypes.json)
        try await responseWriter.commitAndCompleteWith(encodedError)
    }
}
