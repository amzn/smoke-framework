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
// StandardLambdaHTTP1ProxyResponseHandler.swift
// SmokeOperationsHTTP1LambdaProxy
//

import Foundation
import NIO
import NIOHTTP1
import SmokeOperations
import SmokeOperationsHTTP1
import AWSLambdaRuntime
import AWSLambdaEvents
import Logging

private struct HTTP1Headers {
    /// Content-Length Header
    public static let contentLength = "Content-Length"

    /// Content-Type Header
    public static let contentType = "Content-Type"
}

/**
 Handles the response to a HTTP request.
*/
public struct StandardLambdaHTTP1ProxyResponseHandler: LambdaHTTP1ProxyResponseHandler {
    public typealias InvocationContext = SmokeInvocationContext<Lambda.Context>
    
    let requestHead: HTTPRequestHead
    let eventLoop: EventLoop
    let callback: (Result<APIGateway.Response, Error>) -> Void
    
    public init(requestHead: HTTPRequestHead,
                eventLoop: EventLoop,
                callback: @escaping (Result<APIGateway.Response, Error>) -> Void) {
        self.requestHead = requestHead
        self.eventLoop = eventLoop
        self.callback = callback
    }
    
    public func executeInEventLoop(invocationContext: InvocationContext, execute: @escaping () -> ()) {
        // if we are currently on a thread that can complete the response
        if eventLoop.inEventLoop {
            execute()
        } else {
            // otherwise execute on a thread that can
            eventLoop.execute {
                execute()
            }
        }
    }
    
    public func complete(invocationContext: InvocationContext, status: NIOHTTP1.HTTPResponseStatus,
                         responseComponents: HTTP1ServerResponseComponents) {
        let bodySize = handleComplete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        
        invocationContext.invocationReporting.logger.info(
            "Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    public func completeInEventLoop(invocationContext: InvocationContext, status: NIOHTTP1.HTTPResponseStatus,
                                    responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.complete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    public func completeSilently(invocationContext: InvocationContext, status: NIOHTTP1.HTTPResponseStatus,
                                 responseComponents: HTTP1ServerResponseComponents) {
        let bodySize = handleComplete(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        
        invocationContext.invocationReporting.logger.debug(
            "Http response send: status '\(status.code)', body size '\(bodySize)'")
    }
    
    public func completeSilentlyInEventLoop(invocationContext: InvocationContext, status: NIOHTTP1.HTTPResponseStatus,
                                            responseComponents: HTTP1ServerResponseComponents) {
        executeInEventLoop(invocationContext: invocationContext) {
            self.completeSilently(invocationContext: invocationContext, status: status, responseComponents: responseComponents)
        }
    }
    
    private func handleComplete(invocationContext: InvocationContext, status: NIOHTTP1.HTTPResponseStatus,
                                responseComponents: HTTP1ServerResponseComponents) -> Int {
        var multiValueHeaders: [String: [String]] = [:]
        
        let bodyString: String?
        let bodySize: Int
        
        // if there is a body
        if let body = responseComponents.body {
            bodyString = String(data: body.data, encoding: .utf8)
            bodySize = body.data.count
            
            // add the content type header
            multiValueHeaders[HTTP1Headers.contentType] = [body.contentType]
        } else {
            bodyString = nil
            bodySize = 0
        }
        
        // add the content length header and write the response head to the response
        multiValueHeaders[HTTP1Headers.contentLength] = ["\(bodySize)"]
        
        // add any additional headers
        responseComponents.additionalHeaders.forEach { header in
            if var updatedHeaderValues = multiValueHeaders[header.0] {
                updatedHeaderValues.append(header.1)
                multiValueHeaders[header.0] = updatedHeaderValues
            } else {
                multiValueHeaders[header.0] = [header.1]
            }
        }
        
        let headers = multiValueHeaders.compactMapValues { values -> String? in
            values.first
        }
        
        let response = APIGateway.Response(statusCode: AWSLambdaEvents.HTTPResponseStatus(code: status.code, reasonPhrase: status.reasonPhrase),
                                           headers: headers,
                                           multiValueHeaders: multiValueHeaders,
                                           body: bodyString,
                                           isBase64Encoded: false)
        
        callback(.success(response))
        
        return bodySize
    }
}
