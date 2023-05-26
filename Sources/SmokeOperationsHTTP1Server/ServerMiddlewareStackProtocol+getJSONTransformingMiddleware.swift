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
//  ServerMiddlewareStackProtocol+getJSONTransformingMiddleware.swift
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations
import SmokeOperationsHTTP1
import SmokeHTTP1ServerMiddleware

public extension ServerMiddlewareStackProtocol {
    func getWithInputWithOutputJSONTransformingMiddleware<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                                          InnerMiddlewareType: TransformingMiddlewareProtocol>(
        from _: OuterMiddlewareType, to _: InnerMiddlewareType, statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                      InnerMiddlewareType.IncomingInput,
                                      JSONTypedOutputWriter<InnerMiddlewareType.IncomingOutputWriter.OutputType,
                                                            OuterMiddlewareType.OutgoingOutputWriter>,
                                      OuterMiddlewareType.OutgoingContext>
    where OuterMiddlewareType.IncomingOutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.IncomingOutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.IncomingOutputWriter.OutputType: OperationHTTP1OutputProtocol,
    InnerMiddlewareType.IncomingInput: OperationHTTP1InputProtocol,
    OuterMiddlewareType.OutgoingContext: ContextWithPathShape {
        return JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                              InnerMiddlewareType.IncomingInput,
                                              JSONTypedOutputWriter<InnerMiddlewareType.IncomingOutputWriter.OutputType,
                                                                    OuterMiddlewareType.OutgoingOutputWriter>,
                                              OuterMiddlewareType.OutgoingContext> { wrappedWriter in
            JSONTypedOutputWriter<InnerMiddlewareType.IncomingOutputWriter.OutputType,
                                  OuterMiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    func getWithInputWithOutputJSONTransformingMiddleware<InnerMiddlewareType: TransformingMiddlewareProtocol>(
        to _: InnerMiddlewareType, statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<RouterType.OutputWriter,
                                      InnerMiddlewareType.IncomingInput,
                                      JSONTypedOutputWriter<InnerMiddlewareType.IncomingOutputWriter.OutputType,
                                                            RouterType.OutputWriter>,
                                      RouterType.OutgoingMiddlewareContext>
    where RouterType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.IncomingOutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.IncomingOutputWriter.OutputType: OperationHTTP1OutputProtocol,
    InnerMiddlewareType.IncomingInput: OperationHTTP1InputProtocol,
    RouterType.OutgoingMiddlewareContext: ContextWithPathShape {
        return JSONRequestTransformMiddleware<RouterType.OutputWriter,
                                              InnerMiddlewareType.IncomingInput,
                                              JSONTypedOutputWriter<InnerMiddlewareType.IncomingOutputWriter.OutputType,
                                                                    RouterType.OutputWriter>,
                                              RouterType.OutgoingMiddlewareContext> { wrappedWriter in
            JSONTypedOutputWriter<InnerMiddlewareType.IncomingOutputWriter.OutputType,
                                  RouterType.OutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    func getWithInputWithOutputJSONTransformingMiddleware<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                                          Input, Output, ApplicationContextType>(
                                                            from _: OuterMiddlewareType,
                                                            forOperation _: @Sendable (Input, ApplicationContextType) -> Output,
                                                            statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                      Input,
                                      JSONTypedOutputWriter<Output,
                                                            OuterMiddlewareType.OutgoingOutputWriter>,
                                      OuterMiddlewareType.OutgoingContext>
    where OuterMiddlewareType.IncomingOutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.OutgoingContext: ContextWithPathShape {
        return JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                              Input,
                                              JSONTypedOutputWriter<Output,
                                                                    OuterMiddlewareType.OutgoingOutputWriter>,
                                              OuterMiddlewareType.OutgoingContext> { wrappedWriter in
            JSONTypedOutputWriter<Output,
                                  OuterMiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    func getWithInputWithOutputJSONTransformingMiddleware<OuterMiddlewareType: TransformingMiddlewareProtocol,
                                                          Input, Output, ApplicationContextType>(
                                                            from _: OuterMiddlewareType,
                                                            forOperationProvider _: (ApplicationContextType) -> (@Sendable (Input) async throws
                                                                                                                 -> Output),
                                                            statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                      Input,
                                      JSONTypedOutputWriter<Output,
                                                            OuterMiddlewareType.OutgoingOutputWriter>,
                                      OuterMiddlewareType.OutgoingContext>
    where OuterMiddlewareType.IncomingOutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.OutgoingContext: ContextWithPathShape {
        return JSONRequestTransformMiddleware<OuterMiddlewareType.OutgoingOutputWriter,
                                              Input,
                                              JSONTypedOutputWriter<Output,
                                                                    OuterMiddlewareType.OutgoingOutputWriter>,
                                              OuterMiddlewareType.OutgoingContext> { wrappedWriter in
            JSONTypedOutputWriter<Output,
                                  OuterMiddlewareType.OutgoingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    func getWithInputWithOutputJSONTransformingMiddleware<Input, Output, ApplicationContextType>(
        forOperation _: @Sendable (Input, ApplicationContextType) -> Output,
        statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<RouterType.OutputWriter,
                                      Input,
                                      JSONTypedOutputWriter<Output,
                                                            RouterType.OutputWriter>,
                                      RouterType.OutgoingMiddlewareContext>
    where RouterType.OutputWriter: HTTPServerResponseWriterProtocol,
    RouterType.OutgoingMiddlewareContext: ContextWithPathShape {
        return JSONRequestTransformMiddleware<RouterType.OutputWriter,
                                              Input,
                                              JSONTypedOutputWriter<Output,
                                                                    RouterType.OutputWriter>,
                                              RouterType.OutgoingMiddlewareContext> { wrappedWriter in
            JSONTypedOutputWriter<Output,
                                  RouterType.OutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    func getWithInputWithOutputJSONTransformingMiddleware<Input, Output, ApplicationContextType>(
        forOperationProvider _: (ApplicationContextType) -> (@Sendable (Input) async throws -> Output),
        statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<RouterType.OutputWriter,
                                      Input,
                                      JSONTypedOutputWriter<Output,
                                                            RouterType.OutputWriter>,
                                      RouterType.OutgoingMiddlewareContext>
    where RouterType.OutputWriter: HTTPServerResponseWriterProtocol,
    RouterType.OutgoingMiddlewareContext: ContextWithPathShape {
        return JSONRequestTransformMiddleware<RouterType.OutputWriter,
                                              Input,
                                              JSONTypedOutputWriter<Output,
                                                                    RouterType.OutputWriter>,
                                              RouterType.OutgoingMiddlewareContext> { wrappedWriter in
            JSONTypedOutputWriter<Output,
                                  RouterType.OutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
}
