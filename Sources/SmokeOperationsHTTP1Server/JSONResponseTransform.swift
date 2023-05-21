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
//  JSONResponseTransform.swift
//  SmokeOperationsHTTP1Server
//

import Foundation
import SwiftMiddleware
import SmokeHTTP1ServerMiddleware
import SmokeAsyncHTTP1Server
import HTTPHeadersCoding
import NIOHTTP1
import SmokeOperationsHTTP1

private let maxBodySize = 1024 * 1024 // 1 MB

public struct JSONResponseTransform<InputType: OperationHTTP1OutputProtocol,
                                        Context: ContextWithMutableLogger & ContextWithResponseWriter>: TransformProtocol {
    private let status: HTTPResponseStatus
    
    public init(status: HTTPResponseStatus) {
        self.status = status
    }
    
    public func transform(_ input: InputType, context: Context) async throws {
        let responseWriter = context.responseWriter
        await responseWriter.setStatus(self.status)
        
        if let additionalHeadersEncodable = input.additionalHeadersEncodable {
            let headers = try HTTPHeadersEncoder().encode(additionalHeadersEncodable)
            
            await responseWriter.updateHeaders { responseHeaders in
                headers.forEach { header in
                    guard let value = header.1 else {
                        return
                    }
                    
                    responseHeaders.add(name: header.0, value: value)
                }
            }
        }
        
        if let bodyEncodable = input.bodyEncodable {
            let encodedOutput = try JSONEncoder.getFrameworkEncoder().encode(bodyEncodable)
            
            await responseWriter.setContentType(MimeTypes.json)
            try await responseWriter.commitAndCompleteWith(encodedOutput)
        }
    }
}
