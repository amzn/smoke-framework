// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
import ShapeCoding
import Logging

internal struct PingParameters {
    static let uri = "/ping"
    static let payload = "Ping completed.".data(using: .utf8) ?? Data()
}

/**
 Implementation of the HttpRequestHandler protocol that handles an
 incoming Http request as an operation.
 */
struct OperationServerHTTP1RequestHandler<ContextType, SelectorType, OperationIdentifer>: HTTP1RequestHandler
        where SelectorType: SmokeHTTP1HandlerSelector, SelectorType.ContextType == ContextType,
        SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
        HTTP1ResponseHandler == SelectorType.DefaultOperationDelegateType.ResponseHandlerType,
        SelectorType.OperationIdentifer == OperationIdentifer {
    let handlerSelector: SelectorType
    let context: ContextType
    let pingRequestReporting: SmokeServerRequestReporting
    let unknownOperationRequestReporting: SmokeServerRequestReporting
    let errorDeterminingOperationRequestReporting: SmokeServerRequestReporting
    
    init(handlerSelector: SelectorType, context: ContextType, serverName: String,
         reportingConfiguration: SmokeServerReportingConfiguration<OperationIdentifer>) {
        self.handlerSelector = handlerSelector
        self.context = context
        
        self.pingRequestReporting = SmokeServerRequestReporting(serverName: serverName, request: .ping,
                                                                configuration: reportingConfiguration)
        self.unknownOperationRequestReporting = SmokeServerRequestReporting(serverName: serverName, request: .unknownOperation,
                                                                            configuration: reportingConfiguration)
        self.errorDeterminingOperationRequestReporting = SmokeServerRequestReporting(serverName: serverName,
                                                                                     request: .errorDeterminingOperation,
                                                                                     configuration: reportingConfiguration)
    }

    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: HTTP1ResponseHandler,
                       invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String) {
        func getInvocationContextForAnonymousRequest(requestReporting: SmokeServerRequestReporting) -> SmokeServerInvocationContext {
            var decoratedRequestLogger: Logger = requestLogger
            handlerSelector.defaultOperationDelegate.decorateLoggerForAnonymousRequest(requestLogger: &decoratedRequestLogger)
            
            let invocationReporting = SmokeServerInvocationReporting(logger: decoratedRequestLogger,
                                                                     internalRequestId: internalRequestId)
            return SmokeServerInvocationContext(invocationReporting: invocationReporting,
                                                requestReporting: requestReporting)
        }
        
        // this is the ping url
        if requestHead.uri == PingParameters.uri {
            let body = (contentType: "text/plain", data: PingParameters.payload)
            let responseComponents = HTTP1ServerResponseComponents(additionalHeaders: [], body: body)
            let invocationContext = getInvocationContextForAnonymousRequest(requestReporting: pingRequestReporting)
            responseHandler.completeSilentlyInEventLoop(invocationContext: invocationContext,
                                                        status: .ok, responseComponents: responseComponents)
            
            return
        }
        
        let uriComponents = requestHead.uri.split(separator: "?", maxSplits: 1)
        let path = String(uriComponents[0])
        let query = uriComponents.count > 1 ? String(uriComponents[1]) : ""

        // get the handler to use
        let handler: OperationHandler<ContextType, SmokeHTTP1RequestHead, HTTP1ResponseHandler, OperationIdentifer>
        let shape: Shape
        let defaultOperationDelegate = handlerSelector.defaultOperationDelegate
        
        do {
            (handler, shape) = try handlerSelector.getHandlerForOperation(
                path,
                httpMethod: requestHead.method, requestLogger: requestLogger)
        } catch SmokeOperationsError.invalidOperation(reason: let reason) {
            let smokeHTTP1RequestHead = SmokeHTTP1RequestHead(httpRequestHead: requestHead,
                                                              query: query,
                                                              pathShape: .null)
            
            let invocationContext = getInvocationContextForAnonymousRequest(requestReporting: unknownOperationRequestReporting)
            defaultOperationDelegate.handleResponseForInvalidOperation(
                requestHead: smokeHTTP1RequestHead,
                message: reason,
                responseHandler: responseHandler,
                invocationContext: invocationContext)
            return
        } catch {
            requestLogger.error("Unexpected handler selection error: \(error))")
            let smokeHTTP1RequestHead = SmokeHTTP1RequestHead(httpRequestHead: requestHead,
                                                              query: query,
                                                              pathShape: .null)
            
            let invocationContext = getInvocationContextForAnonymousRequest(requestReporting: errorDeterminingOperationRequestReporting)
            defaultOperationDelegate.handleResponseForInternalServerError(
                requestHead: smokeHTTP1RequestHead,
                responseHandler: responseHandler,
                invocationContext: invocationContext)
            return
        }
        
        let smokeHTTP1RequestHead = SmokeHTTP1RequestHead(httpRequestHead: requestHead,
                                                          query: query,
                                                          pathShape: shape)
        
        // let it be handled
        handler.handle(smokeHTTP1RequestHead, body: body, withContext: context,
                       responseHandler: responseHandler, invocationStrategy: invocationStrategy,
                       requestLogger: requestLogger, internalRequestId: internalRequestId)
    }
}
