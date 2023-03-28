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
import NIOHTTP1
import SmokeOperations
import SmokeOperationsHTTP1
import Logging
import NIO
import SmokeAsyncHTTP1Server
import ServiceLifecycle

public extension AsyncHTTPServer {
    
    static func runAsOperationServer<InitializerType: SmokeAsyncServerStaticContextInitializer>(
        _ factory: @escaping (EventLoopGroup) async throws -> InitializerType) async
    where InitializerType.MiddlewareContext == SmokeMiddlewareContext {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try await factory(eventLoopGroup)
        } catch {
            let logger = Logger.init(label: "application.initialization")
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
            return
        }
        
        let serverConfiguration = initalizer.serverConfiguration
        
        // initialize the logger after instatiating the initializer
        let logger = Logger.init(label: "application.initialization")
        
        let eventLoopProvider: AsyncHTTPServer.EventLoopProvider
        // if the initializer is indicating to create new threads for the server
        // just use the created eventLoopGroup
        if case .spawnNewThreads = serverConfiguration.eventLoopProvider {
            eventLoopProvider = .use(eventLoopGroup)
        } else {
            // use what the initializer says
            eventLoopProvider = serverConfiguration.eventLoopProvider
        }
        
        @Sendable func getInvocationContext(requestContext: HTTPServerRequestContext<InitializerType.OperationIdentifer>)
        -> InitializerType.MiddlewareStackType.ApplicationContextType {
            return initalizer.getInvocationContext()
        }
        
        var middlewareStack = InitializerType.MiddlewareStackType(
            serverConfiguration: serverConfiguration, applicationContextProvider: getInvocationContext)
        initalizer.operationsInitializer(&middlewareStack)
                
        let server = AsyncHTTPServer(handler: middlewareStack.handle,
                                     port: serverConfiguration.port,
                                     defaultLogger: serverConfiguration.defaultLogger,
                                     eventLoopProvider: eventLoopProvider)
        
        let serviceRunner = ServiceRunner(
          services: [server],
          configuration: .init(gracefulShutdownSignals: serverConfiguration.shutdownOnSignals),
          logger: logger
        )

        do {
            try await serviceRunner.run()
            
            try await initalizer.onShutdown()
            
            try await eventLoopGroup.shutdownGracefully()
        } catch {
            logger.error("Service Runner error.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
    
    static func runAsOperationServer<InitializerType: SmokeAsyncServerPerInvocationContextInitializer>(
        _ factory: @escaping (EventLoopGroup) async throws -> InitializerType) async
    where InitializerType.MiddlewareContext == SmokeMiddlewareContext {
        let eventLoopGroup =
            MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let initalizer: InitializerType
        do {
            initalizer = try await factory(eventLoopGroup)
        } catch {
            let logger = Logger.init(label: "application.initialization")
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
            return
        }
        
        let serverConfiguration = initalizer.serverConfiguration
        
        // initialize the logger after instatiating the initializer
        let logger = Logger.init(label: "application.initialization")
        
        let eventLoopProvider: AsyncHTTPServer.EventLoopProvider
        // if the initializer is indicating to create new threads for the server
        // just use the created eventLoopGroup
        if case .spawnNewThreads = serverConfiguration.eventLoopProvider {
            eventLoopProvider = .use(eventLoopGroup)
        } else {
            // use what the initializer says
            eventLoopProvider = serverConfiguration.eventLoopProvider
        }
        
        var middlewareStack = InitializerType.MiddlewareStackType(
            serverConfiguration: serverConfiguration, applicationContextProvider: initalizer.getInvocationContext)
        initalizer.operationsInitializer(&middlewareStack)
                
        let server = AsyncHTTPServer(handler: middlewareStack.handle,
                                     port: serverConfiguration.port,
                                     defaultLogger: serverConfiguration.defaultLogger,
                                     eventLoopProvider: eventLoopProvider)
        
        let serviceRunner = ServiceRunner(
          services: [server],
          configuration: .init(gracefulShutdownSignals: serverConfiguration.shutdownOnSignals),
          logger: logger
        )

        do {
            try await serviceRunner.run()
            
            try await initalizer.onShutdown()
            
            try await eventLoopGroup.shutdownGracefully()
        } catch {
            logger.error("Service Runner error.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
}
