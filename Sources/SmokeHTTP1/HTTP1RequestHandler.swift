// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// HTTP1RequestHandler.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import Logging
import SmokeInvocation

/**
 Protocol that specifies a handler for a HttpRequest.
 */
public protocol HTTP1RequestHandler {
    associatedtype ResponseHandlerType: ChannelHTTP1ResponseHandler
    
    /**
     Handles an incoming request.
 
     - Parameters:
        - requestHead: the parameters specified in the head of the HTTP request.
        - body: the body of the request, if any.
        - responseHandler: a handler that can be used to respond to the request.
        - invocationStrategy: the invocationStrategy to use for this request.
        - requestLogger: the logger to use for this request.
        - internalRequestId: the internal identifier for this request.
     */
    func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String)
    
    /**
     Handles an incoming request.
 
     - Parameters:
         - requestHead: the parameters specified in the head of the HTTP request.
         - body: the body of the request, if any.
         - responseHandler: a handler that can be used to respond to the request.
         - invocationStrategy: the invocationStrategy to use for this request.
         - requestLogger: the logger to use for this request.
         - eventLoop: the event loop used for this request.
         - internalRequestId: the internal identifier for this request.
     */
    func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                invocationStrategy: InvocationStrategy, requestLogger: Logger, eventLoop: EventLoop?, internalRequestId: String)
}

public extension HTTP1RequestHandler {
    // The function is being added as a non-breaking change, so add a default implementation that delegates to the existing
    // function that must be implemented.
    func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                invocationStrategy: InvocationStrategy, requestLogger: Logger, eventLoop: EventLoop?, internalRequestId: String) {
        handle(requestHead: requestHead, body: body, responseHandler: responseHandler, invocationStrategy: invocationStrategy,
               requestLogger: requestLogger, internalRequestId: internalRequestId)
    }
}
