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
//  JSONTypedOutputWriter.swift
//  SmokeOperationsHTTP1
//

import Foundation
import NIOHTTP1
import SmokeAsyncHTTP1Server
import HTTPHeadersCoding

public struct JSONTypedOutputWriter<OutputType: OperationHTTP1OutputProtocol,
                                    WrappedWriter: HTTPServerResponseWriterProtocol>: TypedOutputWriterProtocol {
    
    private let status: HTTPResponseStatus
    private let wrappedWriter: WrappedWriter
    
    public init(status: HTTPResponseStatus,
                wrappedWriter: WrappedWriter) {
        self.status = status
        self.wrappedWriter = wrappedWriter
    }
    
    public func write(_ new: OutputType) async throws {
        await wrappedWriter.setStatus(self.status)
        
        if let additionalHeadersEncodable = new.additionalHeadersEncodable {
            let headers = try HTTPHeadersEncoder().encode(additionalHeadersEncodable)
            
            await wrappedWriter.updateHeaders { responseHeaders in
                headers.forEach { header in
                    guard let value = header.1 else {
                        return
                    }
                    
                    responseHeaders.add(name: header.0, value: value)
                }
            }
        }
        
        if let bodyEncodable = new.bodyEncodable {
            let encodedOutput = try JSONEncoder.getFrameworkEncoder().encode(bodyEncodable)
            
            await wrappedWriter.setContentType(MimeTypes.json)
            try await wrappedWriter.commit()
            try await wrappedWriter.bodyPart(encodedOutput)
        } else {
            try await wrappedWriter.commit()
        }
        
        try await wrappedWriter.complete()
    }
}
