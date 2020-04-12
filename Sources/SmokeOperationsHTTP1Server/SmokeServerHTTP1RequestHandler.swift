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
// OperationServerHTTP1RequestHandler.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeOperations
import SmokeOperationsHTTP1
import NIOHTTP1
import SmokeHTTP1
import ShapeCoding
import Logging
import SmokeInvocation

/**
 Implementation of the HttpRequestHandler protocol that handles an
 incoming Http request as an operation.
 */
struct OperationServerHTTP1RequestHandler<SelectorType, TraceContextType>: HTTP1RequestHandler
        where SelectorType: SmokeHTTP1HandlerSelector,
        SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
        SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
        TraceContextType ==
            SelectorType.DefaultOperationDelegateType.InvocationReportingType.TraceContextType,
        HTTPRequestHead == TraceContextType.RequestHeadType,
        SelectorType.DefaultOperationDelegateType.ResponseHandlerType: ChannelHTTP1ResponseHandler & HTTP1ResponseHandler,
        SmokeInvocationContext<SelectorType.DefaultOperationDelegateType.InvocationReportingType> ==
            SelectorType.DefaultOperationDelegateType.ResponseHandlerType.InvocationContext {
    typealias ResponseHandlerType = SelectorType.DefaultOperationDelegateType.ResponseHandlerType
    
    typealias InvocationContext = ResponseHandlerType.InvocationContext
    typealias InvocationReportingType = SelectorType.DefaultOperationDelegateType.InvocationReportingType
    typealias TraceContextType = InvocationReportingType.TraceContextType
        
    let operationRequestHandler: StandardHTTP1OperationRequestHandler<SelectorType>
    
    init(handlerSelector: SelectorType, context: SelectorType.ContextType, serverName: String,
         reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>) {
        self.operationRequestHandler = StandardHTTP1OperationRequestHandler(
            handlerSelector: handlerSelector,
            context: context,
            serverName: serverName,
            reportingConfiguration: reportingConfiguration)
    }
    
    init(handlerSelector: SelectorType,
         contextProvider: @escaping (InvocationReportingType) -> SelectorType.ContextType,
         serverName: String, reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>) {
        self.operationRequestHandler = StandardHTTP1OperationRequestHandler(
            handlerSelector: handlerSelector,
            contextProvider: contextProvider,
            serverName: serverName,
            reportingConfiguration: reportingConfiguration)
    }

    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                       invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String) {
        
        let traceContext = TraceContextType(requestHead: requestHead, bodyData: body)
        var decoratedRequestLogger: Logger = requestLogger
        traceContext.handleInwardsRequestStart(requestHead: requestHead, bodyData: body,
                                               logger: &decoratedRequestLogger, internalRequestId: internalRequestId)
        
        func invocationReportingProvider(logger: Logger) -> SmokeServerInvocationReporting<TraceContextType> {
            return SmokeServerInvocationReporting(logger: logger,
                                                  internalRequestId: internalRequestId, traceContext: traceContext)
        }
        
        // let it be handled
        self.operationRequestHandler.handle(requestHead: requestHead,
                                            body: body,
                                            responseHandler: responseHandler,
                                            invocationStrategy: invocationStrategy,
                                            requestLogger: requestLogger,
                                            internalRequestId: internalRequestId,
                                            invocationReportingProvider: invocationReportingProvider)
    }
}
