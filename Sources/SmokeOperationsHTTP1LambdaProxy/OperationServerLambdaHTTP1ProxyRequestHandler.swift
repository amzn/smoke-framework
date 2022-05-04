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
// OperationServerLambdaHTTP1ProxyRequestHandler.swift
// SmokeOperationsHTTP1LambdaProxy
//

import Foundation
import SmokeOperations
import NIOHTTP1
import ShapeCoding
import Logging
import SmokeInvocation
import SmokeOperationsHTTP1
import AWSLambdaRuntime

/**
 Implementation of the HttpRequestHandler protocol that handles an
 incoming Http request as an operation.
 */
struct OperationServerLambdaHTTP1ProxyRequestHandler<SelectorType>: LambdaHTTP1ProxyRequestHandler
        where SelectorType: SmokeHTTP1HandlerSelector,
        Lambda.Context == SelectorType.DefaultOperationDelegateType.InvocationReportingType,
        SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
        SelectorType.DefaultOperationDelegateType.ResponseHandlerType: LambdaHTTP1ProxyResponseHandler {
    typealias ResponseHandlerType = SelectorType.DefaultOperationDelegateType.ResponseHandlerType
    
    
    typealias InvocationContext = ResponseHandlerType.InvocationContext
        
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
         contextProvider: @escaping (Lambda.Context) -> SelectorType.ContextType,
         serverName: String, reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>) {
        self.operationRequestHandler = StandardHTTP1OperationRequestHandler(
            handlerSelector: handlerSelector,
            contextProvider: contextProvider,
            serverName: serverName,
            reportingConfiguration: reportingConfiguration)
    }

    public func handle(requestHead: HTTPRequestHead, context: Lambda.Context, body: Data?, responseHandler: ResponseHandlerType,
                       invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String) {
        
        func invocationReportingProvider(logger: Logger) -> Lambda.Context {
            return context
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
