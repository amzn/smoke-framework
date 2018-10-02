// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

/**
 A protocol that specifies a handler for a HTTP response.
 */
public protocol HTTP1ResponseHandler {
    
    /**
     Function used to provide a response to a HTTP request.
 
     - Parameters:
        - status: the status to provide in the response.
        - body: the content type and data to use for the response.
     */
    func complete(status: HTTPResponseStatus, body: (contentType: String, data: Data)?)
    
    /**
     Function used to provide a response to a HTTP request. The response will not be
     reported at standard logging levels.
 
     - Parameters:
        - status: the status to provide in the response.
        - body: the content type and data to use for the response.
     */
    func completeSilently(status: HTTPResponseStatus,
                          body: (contentType: String, data: Data)?)
}

public extension HTTP1ResponseHandler {
    func completeSilently(status: HTTPResponseStatus,
                          body: (contentType: String, data: Data)?) {
        complete(status: status, body: body)
    }
}
