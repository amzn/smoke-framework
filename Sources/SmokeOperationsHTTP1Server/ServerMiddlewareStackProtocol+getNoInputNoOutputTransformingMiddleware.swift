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
//  ServerMiddlewareStackProtocol+getNoInputNoOutputTransformingMiddleware.swift
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server

public extension ServerMiddlewareStackProtocol {
    func getNoInputNoOutputTransformingMiddleware<MiddlewareType: TransformingMiddlewareProtocol>(from _: MiddlewareType,
                                                                                                  statusOnSuccess: HTTPResponseStatus)
    -> VoidRequestTransformMiddleware<MiddlewareType.OutgoingOutputWriter,
                                      VoidResponseWriter<MiddlewareType.OutgoingOutputWriter>,
                                      MiddlewareType.OutgoingContext>
    where MiddlewareType.IncomingOutputWriter: HTTPServerResponseWriterProtocol {
        return VoidRequestTransformMiddleware<MiddlewareType.OutgoingOutputWriter,
                                              VoidResponseWriter<MiddlewareType.OutgoingOutputWriter>,
                                              MiddlewareType.OutgoingContext> { wrappedWriter in
            VoidResponseWriter<MiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    func getNoInputNoOutputTransformingMiddleware(statusOnSuccess: HTTPResponseStatus)
    -> VoidRequestTransformMiddleware<RouterType.OutputWriter,
                                      VoidResponseWriter<RouterType.OutputWriter>,
                                      RouterType.OutgoingMiddlewareContext>
    where RouterType.OutputWriter: HTTPServerResponseWriterProtocol {
        return VoidRequestTransformMiddleware<RouterType.OutputWriter,
                                              VoidResponseWriter<RouterType.OutputWriter>,
                                              RouterType.OutgoingMiddlewareContext> { wrappedWriter in
            VoidResponseWriter<RouterType.OutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
}
