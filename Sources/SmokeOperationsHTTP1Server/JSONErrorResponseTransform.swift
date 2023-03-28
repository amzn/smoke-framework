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
//  JSONErrorResponseTransform.swift
//  SmokeOperationsHTTP1Server
//

import Foundation
import SmokeAsyncHTTP1Server
import SmokeHTTP1ServerMiddleware
import SmokeOperations
import Logging
import NIOHTTP1

public struct JSONErrorResponseTransform<Context: ContextWithMutableLogger>: ErrorTransform {
    private let reason: String
    private let errorMessage: String?
    private let status: HTTPResponseStatus
    
    public init(reason: String, errorMessage: String?, status: HTTPResponseStatus) {
        self.reason = reason
        self.errorMessage = errorMessage
        self.status = status
    }
    
    public func transform(_ input: Error, context: Context) -> SmokeAsyncHTTP1Server.HTTPServerResponse {
        let errorResult = SmokeOperationsErrorPayload(errorMessage: self.errorMessage)
        let logger = context.logger ?? Logger(label: "ErrorResponseTransform")
        let encodedError = JSONEncoder.encodePayload(payload: errorResult, logger: logger,
                                                     reason: self.reason)
        
        var response = HTTPServerResponse()
        response.body = HTTPServerResponse.Body.bytes(encodedError, contentType: MimeTypes.json)
        response.status = self.status
        
        return response
    }
}
