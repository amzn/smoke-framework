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
//  JSONRequestTransformMiddleware.swift
//  SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations
import SmokeAsyncHTTP1Server
import NIOFoundationCompat
import SwiftMiddleware
import HTTPPathCoding
import HTTPHeadersCoding
import QueryCoding

private let maxBodySize = 1024 * 1024 // 1 MB

public struct JSONRequestTransformMiddleware<IncomingOutputWriter: HTTPServerResponseWriterProtocol, OutgoingInput: OperationHTTP1InputProtocol,
                                             OutgoingOutputWriter: TypedOutputWriterProtocol, Context: ContextWithPathShape>: TransformingMiddlewareProtocol {
    public typealias IncomingContext = Context
    public typealias OutgoingContext = Context
    
    private let outputWriterTransformer: (IncomingOutputWriter) -> OutgoingOutputWriter
    
    public init(outputWriterTransformer: @escaping (IncomingOutputWriter) -> OutgoingOutputWriter) {
        self.outputWriterTransformer = outputWriterTransformer
    }
    
    public func handle(_ input: HTTPServerRequest,
                       outputWriter: IncomingOutputWriter,
                       context: Context,
                       next: (OutgoingInput, OutgoingOutputWriter, Context) async throws -> Void) async throws {
        func queryDecodableProvider() throws -> OutgoingInput.QueryType {
            let uriComponents = URLComponents(string: input.uri)
            return try QueryDecoder().decode(OutgoingInput.QueryType.self,
                                             from: uriComponents?.query ?? "")
        }
        
        func pathDecodableProvider() throws -> OutgoingInput.PathType {
            return try HTTPPathDecoder().decode(OutgoingInput.PathType.self,
                                                fromShape: context.pathShape)
        }
        
        var bodyByteBuffer = try await input.body.collect(upTo: maxBodySize)
        func bodyDecodableProvider() throws -> OutgoingInput.BodyType {
            let byteBufferSize = bodyByteBuffer.readableBytes
            if byteBufferSize > 0, let newData = bodyByteBuffer.readData(length: byteBufferSize) {
                return try JSONDecoder.getFrameworkDecoder().decode(OutgoingInput.BodyType.self, from: newData)
            } else {
                throw SmokeOperationsError.validationError(reason: "Input body expected; none found.")
            }
        }
        
        func headersDecodableProvider() throws -> OutgoingInput.HeadersType {
            let headers: [(String, String?)] =
                input.headers.map { header in
                    return (header.name, header.value)
                }
            return try HTTPHeadersDecoder().decode(OutgoingInput.HeadersType.self,
                                                   from: headers)
        }
        
        let outgoingInput = try OutgoingInput.compose(queryDecodableProvider: queryDecodableProvider,
                                                      pathDecodableProvider: pathDecodableProvider,
                                                      bodyDecodableProvider: bodyDecodableProvider,
                                                      headersDecodableProvider: headersDecodableProvider)
        let outgoingOutputWriter = self.outputWriterTransformer(outputWriter)
        
        try await next(outgoingInput, outgoingOutputWriter, context)
    }
}
