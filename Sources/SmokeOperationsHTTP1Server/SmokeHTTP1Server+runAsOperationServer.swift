// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// SmokeHTTP1Server+runAsOperationServer.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeHTTP1
import NIOHTTP1
import SmokeOperations
import SmokeOperationsHTTP1
import Logging
import NIO
import AsyncHTTPClient
import SmokeInvocation

public extension SmokeHTTP1Server {
    
    static func runAsOperationServer<InitializerType: SmokeAsyncServerStaticContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoopGroup) async throws -> InitializerType) async
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            StandardHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try await factory(eventLoopGroup)
        } catch {
            let logger = Logger.init(label: "application.initialization")
            
            logger.error("Unable to initialize application from factory due to error - \(error).")
            
            return
        }
        
        // initialize the logger after instatiating the initializer
        let logger = Logger.init(label: "application.initialization")
        
        let eventLoopProvider: SmokeHTTP1Server.EventLoopProvider
        // if the initializer is indicating to create new threads for the server
        // just use the created eventLoopGroup
        if case .spawnNewThreads = initalizer.eventLoopProvider {
            eventLoopProvider = .use(eventLoopGroup)
        } else {
            // use what the initializer says
            eventLoopProvider = initalizer.eventLoopProvider
        }
        
        var handlerSelector = initalizer.handlerSelectorProvider()
        initalizer.operationsInitializer(&handlerSelector)
        
        let handler = OperationServerHTTP1RequestHandler<InitializerType.SelectorType, TraceContextType>(
            handlerSelector: handlerSelector,
            context: initalizer.getInvocationContext(),
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration)
        let server = StandardSmokeHTTP1Server(handler: handler,
                                              port: initalizer.port,
                                              invocationStrategy: initalizer.invocationStrategy,
                                              defaultLogger: initalizer.defaultLogger,
                                              eventLoopProvider: eventLoopProvider,
                                              shutdownOnSignals: initalizer.shutdownOnSignals)
        do {
            try server.start()
            
            try await server.untilShutdown()
            
            try await initalizer.onShutdown()
            
            try await eventLoopGroup.shutdownGracefully()
        } catch {
            logger.error("Operations Server lifecycle error: '\(error)'")
        }
    }
    
    static func runAsOperationServer<InitializerType: SmokeAsyncServerPerInvocationContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoopGroup) async throws -> InitializerType) async
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            StandardHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try await factory(eventLoopGroup)
        } catch {
            let logger = Logger.init(label: "application.initialization")
            
            logger.error("Unable to initialize application from factory due to error - \(error).")
            
            return
        }
        
        // initialize the logger after instatiating the initializer
        let logger = Logger.init(label: "application.initialization")
        
        let eventLoopProvider: SmokeHTTP1Server.EventLoopProvider
        // if the initializer is indicating to create new threads for the server
        // just use the created eventLoopGroup
        if case .spawnNewThreads = initalizer.eventLoopProvider {
            eventLoopProvider = .use(eventLoopGroup)
        } else {
            // use what the initializer says
            eventLoopProvider = initalizer.eventLoopProvider
        }
        
        var handlerSelector = initalizer.handlerSelectorProvider()
        initalizer.operationsInitializer(&handlerSelector)
        
        let handler = OperationServerHTTP1RequestHandler<InitializerType.SelectorType, TraceContextType>(
            handlerSelector: handlerSelector,
            contextProvider: initalizer.getInvocationContext,
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration)
        let server = StandardSmokeHTTP1Server(handler: handler,
                                              port: initalizer.port,
                                              invocationStrategy: initalizer.invocationStrategy,
                                              defaultLogger: initalizer.defaultLogger,
                                              eventLoopProvider: eventLoopProvider,
                                              shutdownOnSignals: initalizer.shutdownOnSignals)
        do {
            try server.start()
            
            try await server.untilShutdown()
            
            try await initalizer.onShutdown()
            
            try await eventLoopGroup.shutdownGracefully()
        } catch {
            logger.error("Operations Server lifecycle error: '\(error)'")
        }
    }
}
