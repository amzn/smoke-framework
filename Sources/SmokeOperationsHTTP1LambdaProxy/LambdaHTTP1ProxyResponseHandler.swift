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
// LambdaHTTP1ProxyResponseHandler.swift
// SmokeOperationsHTTP1LambdaProxy
//

import Foundation
import NIO
import NIOHTTP1
import SmokeOperations
import SmokeOperationsHTTP1
import AWSLambdaRuntime
import AWSLambdaEvents

/**
 A protocol that specifies a handler for a HTTP response.
 */
public protocol LambdaHTTP1ProxyResponseHandler : HTTP1ResponseHandler
    where InvocationContext == SmokeInvocationContext<Lambda.Context> {
    
    /**
     Initializer.
     
     - Parameters:
         - requestHead: the head of the request that this handler will respond to.
     */
    init(requestHead: HTTPRequestHead,
         eventLoop: EventLoop,
         callback: @escaping (Result<APIGateway.Response, Error>) -> Void)
}
