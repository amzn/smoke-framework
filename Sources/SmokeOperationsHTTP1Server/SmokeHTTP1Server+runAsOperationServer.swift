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
        _ factory: @escaping () async throws -> InitializerType) async
    where InitializerType.MiddlewareStackType.RouterType.OutputWriter == HTTPServerResponseWriter {
        let initalizer: InitializerType
        do {
            initalizer = try await factory()
        } catch {
            let logger = Logger.init(label: "application.initialization")
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
            return
        }
        
        let serverConfiguration = initalizer.serverConfiguration
        
        // initialize the logger after instatiating the initializer
        let logger = Logger.init(label: "application.initialization")
                
        @Sendable func getInvocationContext(requestContext: HTTPServerRequestContext<InitializerType.OperationIdentifer>)
        -> InitializerType.MiddlewareStackType.ApplicationContextType {
            return initalizer.getInvocationContext()
        }
        
        var middlewareStack = InitializerType.MiddlewareStackType(
            serverName: initalizer.serverName, serverConfiguration: serverConfiguration, applicationContextProvider: getInvocationContext)
        initalizer.operationsInitializer(&middlewareStack)
                
        let server = AsyncHTTPServer(handler: middlewareStack.handle,
                                     port: serverConfiguration.port,
                                     defaultLogger: serverConfiguration.defaultLogger,
                                     eventLoopGroup: serverConfiguration.eventLoopGroup)
        
        let serviceGroup = ServiceGroup(
          services: [server],
          configuration: .init(gracefulShutdownSignals: serverConfiguration.shutdownOnSignals),
          logger: logger
        )

        do {
            try await serviceGroup.run()
            
            try await initalizer.onShutdown()
            
            if serverConfiguration.eventLoopGroupStatus.owned {
                try await serverConfiguration.eventLoopGroup.shutdownGracefully()
            }
        } catch {
            logger.error("Service Group error.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
    
    static func runAsOperationServer<InitializerType: SmokeAsyncServerPerInvocationContextInitializer>(
        _ factory: @escaping () async throws -> InitializerType) async
    where InitializerType.MiddlewareStackType.RouterType.OutputWriter == HTTPServerResponseWriter {
        let initalizer: InitializerType
        do {
            initalizer = try await factory()
        } catch {
            let logger = Logger.init(label: "application.initialization")
            
            logger.error("Unable to initialize application from factory.",
                         metadata: ["cause": "\(String(describing: error))"])
            
            return
        }
        
        let serverConfiguration = initalizer.serverConfiguration
        
        // initialize the logger after instatiating the initializer
        let logger = Logger.init(label: "application.initialization")
        
        var middlewareStack = InitializerType.MiddlewareStackType(
            serverName: initalizer.serverName, serverConfiguration: serverConfiguration, applicationContextProvider: initalizer.getInvocationContext)
        initalizer.operationsInitializer(&middlewareStack)
                
        let server = AsyncHTTPServer(handler: middlewareStack.handle,
                                     port: serverConfiguration.port,
                                     defaultLogger: serverConfiguration.defaultLogger,
                                     eventLoopGroup: serverConfiguration.eventLoopGroup)

        let serviceGroup = ServiceGroup(
          services: [server],
          configuration: .init(gracefulShutdownSignals: serverConfiguration.shutdownOnSignals),
          logger: logger
        )

        do {
            try await serviceGroup.run()
            
            try await initalizer.onShutdown()
            
            if serverConfiguration.eventLoopGroupStatus.owned {
                try await serverConfiguration.eventLoopGroup.shutdownGracefully()
            }
        } catch {
            logger.error("Service Group error.",
                         metadata: ["cause": "\(String(describing: error))"])
        }
    }
}
