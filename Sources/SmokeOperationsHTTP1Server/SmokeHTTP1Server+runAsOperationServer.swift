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
    @available(swift, deprecated: 3.0, message: "Provide an initializer that accepts an EventLoopGroup instance.")
    static func runAsOperationServer<InitializerType: SmokeServerStaticContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoop) throws -> InitializerType)
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        func wrappedFactory(eventLoopGroup: EventLoopGroup) throws -> InitializerType {
            return try factory(eventLoopGroup.next())
        }
        
        runAsOperationServer(wrappedFactory)
    }
    
    @available(swift, deprecated: 3.0, message: "Provide an initializer that accepts an EventLoopGroup instance.")
    static func runAsOperationServer<InitializerType: SmokeServerPerInvocationContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoop) throws -> InitializerType)
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        func wrappedFactory(eventLoopGroup: EventLoopGroup) throws -> InitializerType {
            return try factory(eventLoopGroup.next())
        }
        
        runAsOperationServer(wrappedFactory)
    }
    
    static func runAsOperationServer<InitializerType: SmokeServerStaticContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoopGroup) throws -> InitializerType)
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try factory(eventLoopGroup)
        } catch {
            // create a logger that will, regardless of what logging backend was bootstrapped, will log immediately
            // to standard out
            let logger = Logger.init(label: "application.initialization") { StreamLogHandler.standardOutput(label: $0) }
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
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
                
        let responser = SmokeServerHBHTTPResponder(
            handlerSelector: initalizer.handlerSelector,
            context: initalizer.getInvocationContext(),
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration,
            invocationStrategy: initalizer.invocationStrategy)
        let server = HBSmokeHTTP1Server(responder: responser,
                                        port: initalizer.port,
                                        defaultLogger: initalizer.defaultLogger,
                                        eventLoopProvider: eventLoopProvider,
                                        shutdownOnSignals: initalizer.shutdownOnSignals)
        
        do {
            try server.start()
            
            try server.waitUntilShutdownAndThen {
                do {
                    try initalizer.onShutdown()
                    
                    try eventLoopGroup.syncShutdownGracefully()
                } catch {
                    logger.error("Unable to shutdown cleanly.",
                                 metadata: ["cause": "\(String(describing: error))"])
                }
            }
        } catch {
            logger.error("Unable to start Operations Server.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
    
    static func runAsOperationServer<InitializerType: SmokeServerPerInvocationContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoopGroup) throws -> InitializerType)
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try factory(eventLoopGroup)
        } catch {
            // create a logger that will, regardless of what logging backend was bootstrapped, will log immediately
            // to standard out
            let logger = Logger.init(label: "application.initialization") { StreamLogHandler.standardOutput(label: $0) }
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
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
                
        let responser = SmokeServerHBHTTPResponder(
            handlerSelector: initalizer.handlerSelector,
            contextProvider: initalizer.getInvocationContext,
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration,
            invocationStrategy: initalizer.invocationStrategy)
        let server = HBSmokeHTTP1Server(responder: responser,
                                        port: initalizer.port,
                                        defaultLogger: initalizer.defaultLogger,
                                        eventLoopProvider: eventLoopProvider,
                                        shutdownOnSignals: initalizer.shutdownOnSignals)
        
        do {
            try server.start()
            
            try server.waitUntilShutdownAndThen {
                do {
                    try initalizer.onShutdown()
                    
                    try eventLoopGroup.syncShutdownGracefully()
                } catch {
                    logger.error("Unable to shutdown cleanly.",
                                 metadata: ["cause": "\(String(describing: error))"])
                }
            }
        } catch {
            logger.error("Unable to start Operations Server.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
    
    static func runAsOperationServer<InitializerType: SmokeServerStaticContextInitializerV2, TraceContextType>(
        _ factory: @escaping (EventLoopGroup) throws -> InitializerType)
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try factory(eventLoopGroup)
        } catch {
            // create a logger that will, regardless of what logging backend was bootstrapped, will log immediately
            // to standard out
            let logger = Logger.init(label: "application.initialization") { StreamLogHandler.standardOutput(label: $0) }
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
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
                
        let responser = SmokeServerHBHTTPResponder(
            handlerSelector: handlerSelector,
            context: initalizer.getInvocationContext(),
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration,
            invocationStrategy: initalizer.invocationStrategy)
        let server = HBSmokeHTTP1Server(responder: responser,
                                        port: initalizer.port,
                                        defaultLogger: initalizer.defaultLogger,
                                        eventLoopProvider: eventLoopProvider,
                                        shutdownOnSignals: initalizer.shutdownOnSignals)
        
        do {
            try server.start()
            
            try server.waitUntilShutdownAndThen {
                do {
                    try initalizer.onShutdown()
                    
                    try eventLoopGroup.syncShutdownGracefully()
                } catch {
                    logger.error("Unable to shutdown cleanly.",
                                 metadata: ["cause": "\(String(describing: error))"])
                }
            }
        } catch {
            logger.error("Unable to start Operations Server.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
    
    static func runAsOperationServer<InitializerType: SmokeServerPerInvocationContextInitializerV2, TraceContextType>(
        _ factory: @escaping (EventLoopGroup) throws -> InitializerType)
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try factory(eventLoopGroup)
        } catch {
            // create a logger that will, regardless of what logging backend was bootstrapped, will log immediately
            // to standard out
            let logger = Logger.init(label: "application.initialization") { StreamLogHandler.standardOutput(label: $0) }
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
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
                
        let responser = SmokeServerHBHTTPResponder(
            handlerSelector: handlerSelector,
            contextProvider: initalizer.getInvocationContext,
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration,
            invocationStrategy: initalizer.invocationStrategy)
        let server = HBSmokeHTTP1Server(responder: responser,
                                        port: initalizer.port,
                                        defaultLogger: initalizer.defaultLogger,
                                        eventLoopProvider: eventLoopProvider,
                                        shutdownOnSignals: initalizer.shutdownOnSignals)
        
        do {
            try server.start()
            
            try server.waitUntilShutdownAndThen {
                do {
                    try initalizer.onShutdown()
                    
                    try eventLoopGroup.syncShutdownGracefully()
                } catch {
                    logger.error("Unable to shutdown cleanly.",
                                 metadata: ["cause": "\(String(describing: error))"])
                }
            }
        } catch {
            logger.error("Unable to start Operations Server.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
    
#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)
    static func runAsOperationServer<InitializerType: SmokeAsyncServerStaticContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoopGroup) async throws -> InitializerType) async
    where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try await factory(eventLoopGroup)
        } catch {
            // create a logger that will, regardless of what logging backend was bootstrapped, will log immediately
            // to standard out
            let logger = Logger.init(label: "application.initialization") { StreamLogHandler.standardOutput(label: $0) }
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
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
                
        let responser = SmokeServerHBHTTPResponder(
            handlerSelector: handlerSelector,
            context: initalizer.getInvocationContext(),
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration,
            invocationStrategy: initalizer.invocationStrategy,
            requestExecutor: initalizer.requestExecutor,
            enableTracingWithSwiftConcurrency: initalizer.enableTracingWithSwiftConcurrency)
        let server = HBSmokeHTTP1Server(responder: responser,
                                        port: initalizer.port,
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
            HBHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try await factory(eventLoopGroup)
        } catch {
            // create a logger that will, regardless of what logging backend was bootstrapped, will log immediately
            // to standard out
            let logger = Logger.init(label: "application.initialization") { StreamLogHandler.standardOutput(label: $0) }
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
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
        
        let responser = SmokeServerHBHTTPResponder(
            handlerSelector: handlerSelector,
            contextProvider: initalizer.getInvocationContext,
            serverName: initalizer.serverName,
            reportingConfiguration: initalizer.reportingConfiguration,
            invocationStrategy: initalizer.invocationStrategy,
            requestExecutor: initalizer.requestExecutor,
            enableTracingWithSwiftConcurrency: initalizer.enableTracingWithSwiftConcurrency)
        let server = HBSmokeHTTP1Server(responder: responser,
                                        port: initalizer.port,
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
#endif
}
