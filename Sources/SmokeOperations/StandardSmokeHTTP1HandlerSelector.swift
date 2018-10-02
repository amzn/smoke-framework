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
//  StandardSmokeHTTP1HandlerSelector.swift
//  SmokeOperations
//

import Foundation
import NIOHTTP1
import LoggerAPI

/**
 Implementation of the SmokeHTTP1HandlerSelector protocol that selects a handler
 based on the case-insensitive uri and HTTP method of the incoming request.
 */
public struct StandardSmokeHTTP1HandlerSelector<ContextType, OperationDelegateType: OperationDelegate>: SmokeHTTP1HandlerSelector {
    private var handlerMapping: [String: [HTTPMethod: OperationHandler<ContextType, OperationDelegateType>]] = [:]
    
    public init() {
    }
    
    /**
     Gets the handler to use for an operation with the provided http request
     head.
 
     - Parameters
        - requestHead: the request head of an incoming operation.
     */
    public func getHandlerForOperation(_ requestHead: HTTPRequestHead) throws -> OperationHandler<ContextType, OperationDelegateType> {
        let lowerCasedUri = requestHead.uri.lowercased()
        let httpMethod = requestHead.method
        
        guard let handler = handlerMapping[lowerCasedUri]?[httpMethod] else {
            throw SmokeOperationsError.invalidOperation(reason: "Invalid operation with uri '\(lowerCasedUri)', method '\(httpMethod)'")
        }
        
        Log.info("Operation handler selected with uri '\(lowerCasedUri)', method '\(httpMethod)'")
            
        return handler
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - httpMethod: the http method to add the handler for.
        - handler: the handler to add.
     */
    public mutating func addHandlerForUri(_ uri: String,
                                          httpMethod: HTTPMethod,
                                          handler: OperationHandler<ContextType, OperationDelegateType>) {
        let lowerCasedUri = uri.lowercased()
        if var methodMapping = handlerMapping[lowerCasedUri] {
            methodMapping[httpMethod] = handler
            handlerMapping[lowerCasedUri] = methodMapping
        } else {
            handlerMapping[lowerCasedUri] = [httpMethod: handler]
        }
    }
}

extension HTTPMethod {
    /// Returns the value of this HTTP method
    var rawValue: String {
        switch self {
        case .GET:
            return "GET"
        case .PUT:
            return "PUT"
        case .ACL:
            return "ACL"
        case .HEAD:
            return "HEAD"
        case .POST:
            return "POST"
        case .COPY:
            return "COPY"
        case .LOCK:
            return "LOCK"
        case .MOVE:
            return "MOVE"
        case .BIND:
            return "BIND"
        case .LINK:
            return "LINK"
        case .PATCH:
            return "PATCH"
        case .TRACE:
            return "TRACE"
        case .MKCOL:
            return "MKCOL"
        case .MERGE:
            return "MERGE"
        case .PURGE:
            return "PURGE"
        case .NOTIFY:
            return "NOTIFY"
        case .SEARCH:
            return "SEARCH"
        case .UNLOCK:
            return "UNLOCK"
        case .REBIND:
            return "REBIND"
        case .UNBIND:
            return "UNBIND"
        case .REPORT:
            return "REPORT"
        case .DELETE:
            return "DELETE"
        case .UNLINK:
            return "UNLINK"
        case .CONNECT:
            return "CONNECT"
        case .MSEARCH:
            return "MSEARCH"
        case .OPTIONS:
            return "OPTIONS"
        case .PROPFIND:
            return "PROPFIND"
        case .CHECKOUT:
            return "CHECKOUT"
        case .PROPPATCH:
            return "PROPPATCH"
        case .SUBSCRIBE:
            return "SUBSCRIBE"
        case .MKCALENDAR:
            return "MKCALENDAR"
        case .MKACTIVITY:
            return "MKACTIVITY"
        case .UNSUBSCRIBE:
            return "UNSUBSCRIBE"
        case .RAW(let value):
            return value
        }
    }
}

extension HTTPMethod: Hashable {
    public var hashValue: Int {
        return rawValue.hashValue
    }
}
