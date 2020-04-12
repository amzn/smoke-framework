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
// StandardHTTP1OperationRequestHandler.swift
// SmokeOperationsHTTP1
//
import Foundation
import SmokeOperations
import NIOHTTP1
import ShapeCoding
import Logging
import SmokeInvocation

internal struct PingParameters {
    static let uri = "/ping"
    static let payload = "Ping completed.".data(using: .utf8) ?? Data()
}

/**
 Implementation of the HttpRequestHandler protocol that handles an
 incoming Http request as an operation.
 */
public struct StandardHTTP1OperationRequestHandler<SelectorType>: HTTP1OperationRequestHandler
        where SelectorType: SmokeHTTP1HandlerSelector,
        SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
        SelectorType.DefaultOperationDelegateType.ResponseHandlerType: HTTP1ResponseHandler,
        SmokeInvocationContext<SelectorType.DefaultOperationDelegateType.InvocationReportingType> == SelectorType.DefaultOperationDelegateType.ResponseHandlerType.InvocationContext {
    public typealias ResponseHandlerType = SelectorType.DefaultOperationDelegateType.ResponseHandlerType
    
    
    typealias InvocationContext = ResponseHandlerType.InvocationContext
    public typealias InvocationReportingType = SelectorType.DefaultOperationDelegateType.InvocationReportingType
        
    let handlerSelector: SelectorType
    let context: PerInvocationContext<SelectorType.ContextType, InvocationReportingType>
    let pingOperationReporting: SmokeOperationReporting
    let unknownOperationReporting: SmokeOperationReporting
    let errorDeterminingOperationReporting: SmokeOperationReporting
    
    public init(handlerSelector: SelectorType, context: SelectorType.ContextType, serverName: String,
         reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>) {
        self.handlerSelector = handlerSelector
        self.context = .static(context)
        
        self.pingOperationReporting = SmokeOperationReporting(serverName: serverName, request: .ping,
                                                                    configuration: reportingConfiguration)
        self.unknownOperationReporting = SmokeOperationReporting(serverName: serverName, request: .unknownOperation,
                                                                       configuration: reportingConfiguration)
        self.errorDeterminingOperationReporting = SmokeOperationReporting(serverName: serverName,
                                                                                request: .errorDeterminingOperation,
                                                                                configuration: reportingConfiguration)
    }
    
    public init(handlerSelector: SelectorType,
         contextProvider: @escaping (InvocationReportingType) -> SelectorType.ContextType,
         serverName: String, reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>) {
        self.handlerSelector = handlerSelector
        self.context = .provider(contextProvider)
        
        self.pingOperationReporting = SmokeOperationReporting(serverName: serverName, request: .ping,
                                                                    configuration: reportingConfiguration)
        self.unknownOperationReporting = SmokeOperationReporting(serverName: serverName, request: .unknownOperation,
                                                                       configuration: reportingConfiguration)
        self.errorDeterminingOperationReporting = SmokeOperationReporting(serverName: serverName,
                                                                                request: .errorDeterminingOperation,
                                                                                configuration: reportingConfiguration)
    }

    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                       invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String,
                       invocationReportingProvider: @escaping (Logger) -> InvocationReportingType) {
        func getInvocationContextForAnonymousRequest(requestReporting: SmokeOperationReporting)
                -> SmokeInvocationContext<InvocationReportingType> {
            var decoratedRequestLogger: Logger = requestLogger
            handlerSelector.defaultOperationDelegate.decorateLoggerForAnonymousRequest(requestLogger: &decoratedRequestLogger)
            
            let invocationReporting = invocationReportingProvider(decoratedRequestLogger)
            return SmokeInvocationContext(invocationReporting: invocationReporting,
                                                requestReporting: requestReporting)
        }
        
        // this is the ping url
        if requestHead.uri == PingParameters.uri {
            let body = (contentType: "text/plain", data: PingParameters.payload)
            let responseComponents = HTTP1ServerResponseComponents(additionalHeaders: [], body: body)
            let invocationContext = getInvocationContextForAnonymousRequest(requestReporting: pingOperationReporting)
            responseHandler.completeSilentlyInEventLoop(invocationContext: invocationContext,
                                                        status: .ok, responseComponents: responseComponents)
            
            return
        }
        
        let uriComponents = requestHead.uri.split(separator: "?", maxSplits: 1)
        let path = String(uriComponents[0])
        let query = uriComponents.count > 1 ? String(uriComponents[1]) : ""

        // get the handler to use
        let handler: OperationHandler<SelectorType.ContextType, SmokeHTTP1RequestHead, InvocationReportingType,
                                      ResponseHandlerType, SelectorType.OperationIdentifer>
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
            
            let invocationContext = getInvocationContextForAnonymousRequest(requestReporting: unknownOperationReporting)
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
            
            let invocationContext = getInvocationContextForAnonymousRequest(requestReporting: errorDeterminingOperationReporting)
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
                       requestLogger: requestLogger, internalRequestId: internalRequestId,
                       invocationReportingProvider: invocationReportingProvider)
    }
}
