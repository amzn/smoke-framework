// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeServerHBHTTPResponder.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import NIOCore
import NIOHTTP1
import HummingbirdCore
import SmokeOperationsHTTP1
import SmokeOperations
import SmokeHTTP1
import Logging
import SmokeInvocation

internal struct SmokeServerHBHTTPResponder<SelectorType, TraceContextType: OperationTraceContext>: HBHTTPResponder
where SelectorType: SmokeHTTP1HandlerSelector,
      SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
      SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
      SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
          HBHTTP1ResponseHandler<SmokeInvocationContext<SmokeServerInvocationReporting<TraceContextType>>> {
    typealias InvocationReportingType = SelectorType.DefaultOperationDelegateType.InvocationReportingType
    typealias InvocationContext = SelectorType.DefaultOperationDelegateType.ResponseHandlerType.InvocationContext
    typealias TraceContextType = InvocationReportingType.TraceContextType
              
    let operationRequestHandler: StandardHTTP1OperationRequestHandler<SelectorType>
    let invocationStrategy: InvocationStrategy
              
    init(handlerSelector: SelectorType, context: SelectorType.ContextType, serverName: String,
         reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>,
         invocationStrategy: InvocationStrategy = GlobalDispatchQueueAsyncInvocationStrategy(),
         requestExecutor: RequestExecutor = .originalEventLoop,
         enableTracingWithSwiftConcurrency: Bool = false) {
        self.operationRequestHandler = StandardHTTP1OperationRequestHandler(
            handlerSelector: handlerSelector,
            context: context,
            serverName: serverName,
            reportingConfiguration: reportingConfiguration,
            requestExecutor: requestExecutor,
            enableTracingWithSwiftConcurrency: enableTracingWithSwiftConcurrency)
        self.invocationStrategy = invocationStrategy
    }
    
    init(handlerSelector: SelectorType,
         contextProvider: @escaping (InvocationReportingType) -> SelectorType.ContextType,
         serverName: String, reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>,
         invocationStrategy: InvocationStrategy = GlobalDispatchQueueAsyncInvocationStrategy(),
         requestExecutor: RequestExecutor = .originalEventLoop,
         enableTracingWithSwiftConcurrency: Bool = false) {
        self.operationRequestHandler = StandardHTTP1OperationRequestHandler(
            handlerSelector: handlerSelector,
            contextProvider: contextProvider,
            serverName: serverName,
            reportingConfiguration: reportingConfiguration,
            requestExecutor: requestExecutor,
            enableTracingWithSwiftConcurrency: enableTracingWithSwiftConcurrency)
        self.invocationStrategy = invocationStrategy
    }
    
    internal func respond(to request: HummingbirdCore.HBHTTPRequest, context: NIOCore.ChannelHandlerContext,
                        onComplete: @escaping (Result<HummingbirdCore.HBHTTPResponse, Error>) -> Void) {
        let headReceiveDate = Date()
        let internalRequestId = UUID().uuidString
        var requestLogger = Logger(label: "com.amazon.SmokeFramework.request.\(internalRequestId)")
        requestLogger[metadataKey: "internalRequestId"] = "\(internalRequestId)"
        
        let bodyReadCompleteFuture: EventLoopFuture<Data?>
        switch request.body {
        case .byteBuffer(let byteBufferOptional):
            let body: Data?
            if var byteBuffer  = byteBufferOptional{
                let byteBufferSize = byteBuffer.readableBytes
                body = byteBuffer.readData(length: byteBufferSize)
            } else {
                body = nil
            }
            
            bodyReadCompleteFuture = context.eventLoop.makeSucceededFuture(body)
        case .stream(let stream):
            var bodyData: Data?
            bodyReadCompleteFuture = stream.consumeAll(on: context.eventLoop) { bodyPart in
                var mutableBodyPart = bodyPart
                let byteBufferSize = mutableBodyPart.readableBytes
                let newBodyPart = mutableBodyPart.readData(length: byteBufferSize)
                
                if let existingBody = bodyData {
                    if let newBodyPart = newBodyPart {
                        bodyData = existingBody + newBodyPart
                    }
                } else {
                    bodyData = newBodyPart
                }
                
                return context.eventLoop.makeSucceededFuture(())
            } .map { _ in
                return bodyData
            }
        }
        
        bodyReadCompleteFuture.whenSuccess { body in
            let smokeInwardsRequestContext = StandardSmokeInwardsRequestContext(headReceiveDate: headReceiveDate,
                                                                                requestStart: Date())
            
            let responseHandler = HBHTTP1ResponseHandler<InvocationContext>(requestHead: request.head,
                                                                            context: context,
                                                                            smokeInwardsRequestContext: smokeInwardsRequestContext,
                                                                            onComplete: onComplete)
            
            func actionsProvider(options: OperationTraceContextOptions?)
            -> StandardHTTP1OperationRequestHandler<SelectorType>.Actions {
                let traceContext = TraceContextType(requestHead: request.head, bodyData: body, options: options)
                
                func requestStartTraceAction() -> Logger {
                    var decoratedRequestLogger: Logger = requestLogger
                    traceContext.handleInwardsRequestStart(requestHead: request.head, bodyData: body,
                                                           logger: &decoratedRequestLogger, internalRequestId: internalRequestId)
                    
                    return decoratedRequestLogger
                }
                
                func invocationReportingProvider(logger: Logger) -> SmokeServerInvocationReporting<TraceContextType> {
                    return SmokeServerInvocationReporting(logger: logger,
                                                          internalRequestId: internalRequestId, traceContext: traceContext,
                                                          eventLoop: context.eventLoop,
                                                          outwardsRequestAggregator: smokeInwardsRequestContext)
                }
                
                return .init(invocationReportingProvider: invocationReportingProvider, requestStartTraceAction: requestStartTraceAction)
            }
            
            // let it be handled
            self.operationRequestHandler.handle(requestHead: request.head,
                                                body: body,
                                                responseHandler: responseHandler,
                                                invocationStrategy: self.invocationStrategy,
                                                requestLogger: requestLogger,
                                                internalRequestId: internalRequestId,
                                                actionsProvider: actionsProvider)
        }
    }
}

