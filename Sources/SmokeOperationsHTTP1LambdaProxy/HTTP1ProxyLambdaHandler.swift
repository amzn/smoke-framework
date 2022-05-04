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
//  HTTP1ProxyLambdaHandler.swift
//  SmokeOperationsHTTP1LambdaProxy
//

import Foundation
import SmokeInvocation
import AWSLambdaRuntime
import AWSLambdaEvents
import NIO
import NIOHTTP1

/**
 Implementation of the SmokeHTTP1HandlerSelector protocol that selects a handler
 based on the case-insensitive uri and HTTP method of the incoming request.
 */
struct HTTP1ProxyLambdaHandler<RequestHandlerType: LambdaHTTP1ProxyRequestHandler>: LambdaHandler {
    public typealias In = APIGateway.Request
    public typealias Out = APIGateway.Response
    
    private let handler: RequestHandlerType
    private let invocationStrategy: InvocationStrategy
    
    init(handler: RequestHandlerType,
         invocationStrategy: InvocationStrategy) {
        self.handler = handler
        self.invocationStrategy = invocationStrategy
    }
    
    private func getHeadersInstance(multiValueHeaders: [String: [String]]?) -> NIOHTTP1.HTTPHeaders {
        var headersArray: [(String, String)] = []
        
        multiValueHeaders?.forEach({ (key, valueArray) in
            valueArray.forEach { value in
                headersArray.append((key, value))
            }
        })
        
        return HTTPHeaders(headersArray)
    }
    
    public func handle(context: Lambda.Context, event payload: APIGateway.Request,
                       callback: @escaping (Result<APIGateway.Response, Error>) -> Void) {
        let logger = context.logger
        let bodyData = payload.body?.data(using: .utf8)
        let headers = getHeadersInstance(multiValueHeaders: payload.multiValueHeaders)
        let method = NIOHTTP1.HTTPMethod(rawValue: payload.httpMethod.rawValue)
        let requestHead = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1),
                                          method: method,
                                          uri: payload.path,
                                          headers: headers)
        
        logger.trace("Handling request body with \(bodyData?.count ?? 0) size.")
                
        // create a response handler for this request
        let responseHandler = RequestHandlerType.ResponseHandlerType(
            requestHead: requestHead,
            eventLoop: context.eventLoop,
            callback: callback)
    
        let currentHandler = handler
        
        // pass to the request handler to complete
        currentHandler.handle(requestHead: requestHead,
                              context: context,
                              body: bodyData,
                              responseHandler: responseHandler,
                              invocationStrategy: invocationStrategy,
                              requestLogger: logger,
                              internalRequestId: context.requestID)
    }
}
