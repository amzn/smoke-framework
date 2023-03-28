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
//  JSONRequestTransform.swift
//  SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import HTTPPathCoding
import HTTPHeadersCoding
import QueryCoding

private let maxBodySize = 1024 * 1024 // 1 MB

public struct JSONRequestTransform<OutputType: OperationHTTP1InputProtocol, Context: ContextWithPathShape>: TransformProtocol {
    
    public func transform(_ input: HTTPServerRequest, context: Context) async throws -> OutputType {
        func queryDecodableProvider() throws -> OutputType.QueryType {
            let uriComponents = URLComponents(string: input.uri)
            return try QueryDecoder().decode(OutputType.QueryType.self,
                                             from: uriComponents?.query ?? "")
        }
        
        func pathDecodableProvider() throws -> OutputType.PathType {
            return try HTTPPathDecoder().decode(OutputType.PathType.self,
                                                fromShape: context.pathShape)
        }
        
        var bodyByteBuffer = try await input.body.collect(upTo: maxBodySize)
        func bodyDecodableProvider() throws -> OutputType.BodyType {
            let byteBufferSize = bodyByteBuffer.readableBytes
            if byteBufferSize > 0, let newData = bodyByteBuffer.readData(length: byteBufferSize) {
                return try JSONDecoder.getFrameworkDecoder().decode(OutputType.BodyType.self, from: newData)
            } else {
                throw SmokeOperationsError.validationError(reason: "Input body expected; none found.")
            }
        }
        
        func headersDecodableProvider() throws -> OutputType.HeadersType {
            let headers: [(String, String?)] =
                input.headers.map { header in
                    return (header.name, header.value)
                }
            return try HTTPHeadersDecoder().decode(OutputType.HeadersType.self,
                                                   from: headers)
        }
        
        return try OutputType.compose(queryDecodableProvider: queryDecodableProvider,
                                      pathDecodableProvider: pathDecodableProvider,
                                      bodyDecodableProvider: bodyDecodableProvider,
                                      headersDecodableProvider: headersDecodableProvider)
    }
}
