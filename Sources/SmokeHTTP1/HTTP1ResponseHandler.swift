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
// HTTP1ResponseHandler.swift
// SmokeHTTP1
//

import Foundation
import NIO
import NIOHTTP1
import SmokeOperations

/**
 A protocol that specifies a handler for a HTTP response.
 */
public protocol HTTP1ResponseHandler {
    associatedtype InvocationContext: HTTP1RequestInvocationContext
    
    /**
     Function used to provide a response to a HTTP request.
 
     - Parameters:
        - invocationContext: the context for the current invocation.
        - status: the status to provide in the response.
        - responseComponents: the components to send in the response.
     */
    func complete(invocationContext: InvocationContext, status: HTTPResponseStatus,
                  responseComponents: HTTP1ServerResponseComponents)
    
    /**
     Function used to provide a response to a HTTP request on the server event loop.
     
     - Parameters:
        - invocationContext: the context for the current invocation.
        - status: the status to provide in the response.
        - responseComponents: the components to send in the response.
     */
    func completeInEventLoop(invocationContext: InvocationContext, status: HTTPResponseStatus,
                             responseComponents: HTTP1ServerResponseComponents)
    
    /**
     Function used to provide a response to a HTTP request. The response will not be
     reported at standard logging levels.
 
     - Parameters:
        - invocationContext: the context for the current invocation.
        - status: the status to provide in the response.
        - body: the content type and data to use for the response.
     */
    func completeSilently(invocationContext: InvocationContext, status: HTTPResponseStatus,
                          responseComponents: HTTP1ServerResponseComponents)
    
    /**
     Function used to provide a response to a HTTP request on the server event loop. The
     response will not be reported at standard logging levels.
     
     - Parameters:
        - invocationContext: the context for the current invocation.
        - status: the status to provide in the response.
        - body: the content type and data to use for the response.
     */
    func completeSilentlyInEventLoop(invocationContext: InvocationContext, status: HTTPResponseStatus,
                                     responseComponents: HTTP1ServerResponseComponents)
    
    /**
     Execute the provided closure in the event loop corresponding to the response.
 
     - Parameters:
        - invocationContext: the context for the current invocation.
        - execute: the closure to execute.
     */
    func executeInEventLoop(invocationContext: InvocationContext, execute: @escaping () -> ())
}

public extension HTTP1ResponseHandler {
    func completeSilently(invocationContext: InvocationContext, status: HTTPResponseStatus,
                          responseComponents: HTTP1ServerResponseComponents) {
        complete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
    }
}
