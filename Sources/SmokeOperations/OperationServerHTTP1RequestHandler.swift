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
// OperationServerHTTP1RequestHandler.swift
// SmokeOperations
//

import Foundation
import NIOHTTP1
import SmokeHTTP1
import LoggerAPI

internal struct PingParameters {
    static let uri = "/ping"
    static let payload = "Ping completed.".data(using: .utf8) ?? Data()
}

/**
 Implementation of the HttpRequestHandler protocol that handles an
 incoming Http request as an operation.
 */
struct OperationServerHTTP1RequestHandler<ContextType, SelectorType, OperationDelegateType>: HTTP1RequestHandler
        where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ContextType,
        SelectorType.OperationDelegateType == OperationDelegateType, OperationDelegateType.RequestType == SmokeHTTP1Request,
        OperationDelegateType.ResponseHandlerType == HTTP1ResponseHandler {
    let handlerSelector: SelectorType
    let context: ContextType
    let defaultOperationDelegate: OperationDelegateType

    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: HTTP1ResponseHandler) {
        // this is the ping url
        if requestHead.uri == PingParameters.uri {
            let body = (contentType: "text/plain", data: PingParameters.payload)
            responseHandler.completeSilently(status: .ok, body: body)
            
            return
        }
        
        let smokeHTTP1Request = SmokeHTTP1Request(httpRequestHead: requestHead, body: body)

        // get the handler to use
        let handler: OperationHandler<ContextType, OperationDelegateType>
                
        do {
            handler = try handlerSelector.getHandlerForOperation(requestHead)
        } catch SmokeOperationsError.invalidOperation(reason: let reason) {
            defaultOperationDelegate.handleResponseForInvalidOperation(request: smokeHTTP1Request,
                                                                       message: reason,
                                                                       responseHandler: responseHandler)
            return
        } catch {
            Log.error("Unexpected handler selection error: \(error))")
            
            defaultOperationDelegate.handleResponseForInternalServerError(request: smokeHTTP1Request,
                                                                          responseHandler: responseHandler)
            return
        }
        
        // let it be handled
        handler.handle(smokeHTTP1Request, withContext: context,
                       defaultOperationDelegate: defaultOperationDelegate,
                       responseHandler: responseHandler)
    }
}
