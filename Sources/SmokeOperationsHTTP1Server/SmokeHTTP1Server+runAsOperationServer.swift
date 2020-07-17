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
    static func runAsOperationServer<InitializerType: SmokeServerStaticContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoop) throws -> InitializerType)
        where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
        InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
        InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
        StandardHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
            func wrappedFactory(eventLoopGroup: EventLoopGroup) throws -> InitializerType {
                try factory(eventLoopGroup.next())
            }
            
            runAsOperationServer(wrappedFactory)
    }
  
    static func runAsOperationServer<InitializerType: SmokeServerPerInvocationContextInitializer, TraceContextType>(
        _ factory: @escaping (EventLoop) throws -> InitializerType)
        where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
        InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
        InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
        StandardHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
            func wrappedFactory(eventLoopGroup: EventLoopGroup) throws -> InitializerType {
                try factory(eventLoopGroup.next())
            }
            
            runAsOperationServer(wrappedFactory)
    }
    
    static func runAsOperationServer<InitializerType: SmokeServerStaticContextInitializer, TraceContextType>(
          _ factory: @escaping (EventLoopGroup) throws -> InitializerType)
          where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
          StandardHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
              let eventLoopGroup =
                  MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
              
              let initalizer: InitializerType
              do {
                  initalizer = try factory(eventLoopGroup)
              } catch {
                  let logger = Logger.init(label: "application.initialization")
                  
                  logger.error("Unable to initialize application from factory due to error - \(error).")
                  
                  return
              }
              
              // initialize the logger after instatiating the initializer
              let logger = Logger.init(label: "application.initialization")
              
              let handler = OperationServerHTTP1RequestHandler<InitializerType.SelectorType, TraceContextType>(
                  handlerSelector: initalizer.handlerSelector,
                  context: initalizer.getInvocationContext(), serverName: initalizer.serverName,
                  reportingConfiguration: initalizer.reportingConfiguration)
              let server = StandardSmokeHTTP1Server(handler: handler,
                                                    port: initalizer.port,
                                                    invocationStrategy: initalizer.invocationStrategy,
                                                    defaultLogger: initalizer.defaultLogger,
                                                    eventLoopProvider: initalizer.eventLoopProvider,
                                                    shutdownOnSignal: initalizer.shutdownOnSignal)
              do {
                  try server.start()
                  
                  try server.waitUntilShutdownAndThen {
                      do {
                          try initalizer.onShutdown()
                          
                          try eventLoopGroup.syncShutdownGracefully()
                      } catch {
                          logger.error("Unable to shutdown cleanly: '\(error)'")
                      }
                  }
              } catch {
                  logger.error("Unable to start Operations Server: '\(error)'")
              }
      }
    
      static func runAsOperationServer<InitializerType: SmokeServerPerInvocationContextInitializer, TraceContextType>(
          _ factory: @escaping (EventLoopGroup) throws -> InitializerType)
          where InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType == SmokeServerInvocationReporting<TraceContextType>,
          InitializerType.SelectorType.DefaultOperationDelegateType.RequestHeadType == SmokeHTTP1RequestHead,
          InitializerType.SelectorType.DefaultOperationDelegateType.ResponseHandlerType ==
          StandardHTTP1ResponseHandler<SmokeInvocationContext<InitializerType.SelectorType.DefaultOperationDelegateType.InvocationReportingType>> {
              let eventLoopGroup =
                  MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
              
              let initalizer: InitializerType
              do {
                  initalizer = try factory(eventLoopGroup)
              } catch {
                  let logger = Logger.init(label: "application.initialization")
                  
                  logger.error("Unable to initialize application from factory due to error - \(error).")

                  return
              }
              
              // initialize the logger after instatiating the initializer
              let logger = Logger.init(label: "application.initialization")
              
              let handler = OperationServerHTTP1RequestHandler<InitializerType.SelectorType, TraceContextType>(
                  handlerSelector: initalizer.handlerSelector,
                  contextProvider: initalizer.getInvocationContext, serverName: initalizer.serverName,
                  reportingConfiguration: initalizer.reportingConfiguration)
              let server = StandardSmokeHTTP1Server(handler: handler,
                                                    port: initalizer.port,
                                                    invocationStrategy: initalizer.invocationStrategy,
                                                    defaultLogger: initalizer.defaultLogger,
                                                    eventLoopProvider: initalizer.eventLoopProvider,
                                                    shutdownOnSignal: initalizer.shutdownOnSignal)
              do {
                  try server.start()
                  
                  try server.waitUntilShutdownAndThen {
                      do {
                          try initalizer.onShutdown()
                          
                          try eventLoopGroup.syncShutdownGracefully()
                      } catch {
                          logger.error("Unable to shutdown cleanly: '\(error)'")
                      }
                  }
              } catch {
                  logger.error("Unable to start Operations Server: '\(error)'")
              }
      }
}
