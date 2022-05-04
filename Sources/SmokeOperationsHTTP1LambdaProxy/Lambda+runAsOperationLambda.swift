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
// Lambda+startAsOperationServer.swift
// SmokeOperationsHTTP1LambdaProxy
//

import Foundation
import AWSLambdaRuntime
import NIO
import SmokeOperationsHTTP1
import SmokeInvocation
import SmokeOperations
import Logging

public extension Lambda {
    static func runAsOperationLambda<InitializerType: SmokeAsyncStaticContextInitializer>(
        _ factory: @escaping (EventLoop) async throws -> InitializerType)
        where InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
        InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == Lambda.Context,
        InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType == StandardLambdaHTTP1ProxyResponseHandler {
            Lambda.run { context -> EventLoopFuture<ByteBufferLambdaHandler> in
                let promise = context.eventLoop.makePromise(of: ByteBufferLambdaHandler.self)
                promise.completeWithTask {
                    let initializer = try await factory(context.eventLoop)
                    
                    var handlerSelector = initializer.handlerSelectorProvider()
                    initializer.operationsInitializer(&handlerSelector)
                    
                    let handler = OperationServerLambdaHTTP1ProxyRequestHandler<InitializerType.SelectorType>(
                        handlerSelector: handlerSelector,
                        context: initializer.getInvocationContext(), serverName: initializer.serverName,
                        reportingConfiguration: initializer.reportingConfiguration)
                    
                    return HTTP1ProxyLambdaHandler(handler: handler,
                                                   invocationStrategy: initializer.invocationStrategy)
                }
                return promise.futureResult
            }
    }
  
    static func runAsOperationLambda<InitializerType: SmokeAsyncPerInvocationContextInitializer>(
        _ factory: @escaping (EventLoop) async throws -> InitializerType)
        where InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
        InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == Lambda.Context,
        InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType == StandardLambdaHTTP1ProxyResponseHandler {
            Lambda.run { context -> EventLoopFuture<ByteBufferLambdaHandler> in
                let promise = context.eventLoop.makePromise(of: ByteBufferLambdaHandler.self)
                promise.completeWithTask {
                    let initializer = try await factory(context.eventLoop)
                    
                    var handlerSelector = initializer.handlerSelectorProvider()
                    initializer.operationsInitializer(&handlerSelector)
                    
                    let handler = OperationServerLambdaHTTP1ProxyRequestHandler<InitializerType.SelectorType>(
                        handlerSelector: handlerSelector,
                        contextProvider: initializer.getInvocationContext, serverName: initializer.serverName,
                        reportingConfiguration: initializer.reportingConfiguration)
                    
                    return HTTP1ProxyLambdaHandler(handler: handler,
                                                   invocationStrategy: initializer.invocationStrategy)
                }
                return promise.futureResult
            }
    }
}
