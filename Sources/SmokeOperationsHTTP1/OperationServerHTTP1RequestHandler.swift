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
// SmokeOperationsHTTP1
//
import Foundation
import SmokeOperations
import NIOHTTP1
import SmokeHTTP1
import LoggerAPI
import ShapeCoding

internal struct PingParameters {
    static let uri = "/ping"
    static let payload = "Ping completed.".data(using: .utf8) ?? Data()
}

/**
 Implementation of the HttpRequestHandler protocol that handles an
 incoming Http request as an operation.
 */
struct OperationServerHTTP1RequestHandler<ContextType, SelectorType>: HTTP1RequestHandler
        where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ContextType,
        SmokeHTTP1Request == SelectorType.DefaultOperationDelegateType.RequestType,
        HTTP1ResponseHandler == SelectorType.DefaultOperationDelegateType.ResponseHandlerType {
    let handlerSelector: SelectorType
    let context: ContextType

    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: HTTP1ResponseHandler) {
        // this is the ping url
        if requestHead.uri == PingParameters.uri {
            let body = (contentType: "text/plain", data: PingParameters.payload)
            let responseComponents = HTTP1ServerResponseComponents(additionalHeaders: [], body: body)
            responseHandler.completeSilently(status: .ok, responseComponents: responseComponents)
            
            return
        }
        
        let uriComponents = requestHead.uri.split(separator: "?", maxSplits: 1)
        let path = String(uriComponents[0])
        let query = uriComponents.count > 1 ? String(uriComponents[1]) : ""

        // get the handler to use
        let handler: OperationHandler<ContextType, SmokeHTTP1Request, HTTP1ResponseHandler>
        let shape: Shape
        let defaultOperationDelegate = handlerSelector.defaultOperationDelegate
        
        do {
            (handler, shape) = try handlerSelector.getHandlerForOperation(
                path,
                httpMethod: requestHead.method)
        } catch SmokeOperationsError.invalidOperation(reason: let reason) {
            let smokeHTTP1Request = SmokeHTTP1Request(httpRequestHead: requestHead,
                                                      query: query,
                                                      pathShape: .null,
                                                      body: body)
            
            defaultOperationDelegate.handleResponseForInvalidOperation(
                request: smokeHTTP1Request,
                message: reason,
                responseHandler: responseHandler)
            return
        } catch {
            Log.error("Unexpected handler selection error: \(error))")
            let smokeHTTP1Request = SmokeHTTP1Request(httpRequestHead: requestHead,
                                                      query: query,
                                                      pathShape: .null,
                                                      body: body)
            
            defaultOperationDelegate.handleResponseForInternalServerError(
                request: smokeHTTP1Request,
                responseHandler: responseHandler)
            return
        }
        
        let smokeHTTP1Request = SmokeHTTP1Request(httpRequestHead: requestHead,
                                                  query: query,
                                                  pathShape: shape,
                                                  body: body)
        
        // let it be handled
        handler.handle(smokeHTTP1Request, withContext: context,
                       responseHandler: responseHandler)
    }
}
