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
// SmokeLoggerMiddleware.swift
// SmokeAsyncHTTP1Middleware
//

import Foundation
import SmokeAsyncHTTP1Server
import Logging

public struct SmokeLoggerMiddleware<ResponseBodyStreamType: AsyncSequence,
                                    Context: ContextWithMutableLogger & ContextWithMutableRequestId>: _MiddlewareProtocol
where ResponseBodyStreamType.Element == Data {
    public typealias Input = SmokeHTTP1Request
    public typealias Output = SmokeHTTP1Response<ResponseBodyStreamType>
    
    public func handle(_ input: SmokeAsyncHTTP1Server.SmokeHTTP1Request, context: Context,
                       next: (SmokeHTTP1Request, Context) async throws -> SmokeHTTP1Response<ResponseBodyStreamType>) async throws
    -> SmokeAsyncHTTP1Server.SmokeHTTP1Response<ResponseBodyStreamType> {
        var newLogger = Logger(label: "com.amazon.SmokeFramework.request")
        
        if let internalRequestId = context.internalRequestId {
            newLogger[metadataKey: "internalRequestId"] = "\(internalRequestId)"
        }
        
        var updatedContext = context
        updatedContext.logger = newLogger
        
        return try await next(input, updatedContext)
    }
}
