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
//  VoidRequestTransformMiddleware.swift
//  SmokeOperationsHTTP1Server
//

import Foundation
import SmokeOperations
import SmokeAsyncHTTP1Server
import NIOFoundationCompat
import SwiftMiddleware
import HTTPPathCoding
import HTTPHeadersCoding
import QueryCoding
import SmokeOperationsHTTP1

private let maxBodySize = 1024 * 1024 // 1 MB

public struct VoidRequestTransformMiddleware<IncomingOutputWriter: HTTPServerResponseWriterProtocol,
                                             OutgoingOutputWriter: TypedOutputWriterProtocol, Context>: TransformingMiddlewareProtocol {
    public typealias IncomingContext = Context
    public typealias OutgoingContext = Context
    
    private let outputWriterTransformer: (IncomingOutputWriter) -> OutgoingOutputWriter
    
    public init(outputWriterTransformer: @escaping (IncomingOutputWriter) -> OutgoingOutputWriter) {
        self.outputWriterTransformer = outputWriterTransformer
    }
    
    public func handle(_ input: HTTPServerRequest,
                       outputWriter: IncomingOutputWriter,
                       context: Context,
                       next: ((), OutgoingOutputWriter, Context) async throws -> Void) async throws {
        let outgoingOutputWriter = self.outputWriterTransformer(outputWriter)
        
        try await next((), outgoingOutputWriter, context)
    }
}
