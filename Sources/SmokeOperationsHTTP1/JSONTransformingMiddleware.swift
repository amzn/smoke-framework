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
//  JSONTransformingMiddleware.swift
//  SmokeOperationsHTTP1
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations

public enum JSONTransformingMiddleware {
    public static func withInputAndWithOutput<IncomingOutputWriter: HTTPServerResponseWriterProtocol,
                                              OutgoingInput: OperationHTTP1InputProtocol,
                                              OutputType: OperationHTTP1OutputProtocol,
                                              Context: ContextWithPathShape>(statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<IncomingOutputWriter,
                                      OutgoingInput,
                                      JSONTypedOutputWriter<OutputType, IncomingOutputWriter>,
                                      Context> {
        return JSONRequestTransformMiddleware<IncomingOutputWriter,
                                              OutgoingInput,
                                              JSONTypedOutputWriter<OutputType, IncomingOutputWriter>,
                                              Context> { wrappedWriter in
            JSONTypedOutputWriter<OutputType, IncomingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    public static func withInputAndWithNoOutput<IncomingOutputWriter: HTTPServerResponseWriterProtocol,
                                                OutgoingInput: OperationHTTP1InputProtocol,
                                                Context: ContextWithPathShape>(statusOnSuccess: HTTPResponseStatus)
    -> JSONRequestTransformMiddleware<IncomingOutputWriter,
                                      OutgoingInput,
                                      VoidResponseWriter<IncomingOutputWriter>,
                                      Context> {
        return JSONRequestTransformMiddleware<IncomingOutputWriter,
                                              OutgoingInput,
                                              VoidResponseWriter<IncomingOutputWriter>,
                                              Context> { wrappedWriter in
            VoidResponseWriter<IncomingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
    
    public static func withNoInputAndWithOutput<IncomingOutputWriter: HTTPServerResponseWriterProtocol,
                                                OutputType: OperationHTTP1OutputProtocol,
                                                Context: ContextWithPathShape>(statusOnSuccess: HTTPResponseStatus)
    -> VoidRequestTransformMiddleware<IncomingOutputWriter,
                                      JSONTypedOutputWriter<OutputType, IncomingOutputWriter>,
                                      Context> {
        return VoidRequestTransformMiddleware<IncomingOutputWriter,
                                              JSONTypedOutputWriter<OutputType, IncomingOutputWriter>,
                                              Context> { wrappedWriter in
            JSONTypedOutputWriter<OutputType, IncomingOutputWriter>(status: statusOnSuccess, wrappedWriter: wrappedWriter)
        }
    }
}
