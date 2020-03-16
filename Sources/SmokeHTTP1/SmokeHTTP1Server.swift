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
// SmokeHTTP1Server.swift
// SmokeHTTP1
//

import Foundation
import NIO
import SmokeOperations

public struct ServerDefaults {
    static let defaultHost = "0.0.0.0"
    public static let defaultPort = 8080
}

public enum SmokeHTTP1ServerError: Error {
    case shutdownAttemptOnUnstartedServer
}

/**
 A basic non-blocking HTTP server that handles a request with an
 optional body and returns a response with an optional body.
 
 This implementation wraps an `StandardSmokeHTTP1Server` instance internally, type erasing the generic parameters and
 presenting the same external methods as SmokeFramework 1.x.
 */
public class SmokeHTTP1Server {
    
    /**
     Enumeration specifying how the event loop is provided for a channel established by this client.
     */
    public enum EventLoopProvider {
        /// The client will create a new EventLoopGroup to be used for channels created from
        /// this client. The EventLoopGroup will be closed when this client is closed.
        case spawnNewThreads
        /// The client will use the provided EventLoopGroup for channels created from
        /// this client. This EventLoopGroup will not be closed when this client is closed.
        case use(EventLoopGroup)
    }
    
    /**
     Enumeration specifying if the server should be shutdown on any signals received.
     */
    public enum ShutdownOnSignal {
        // do not shut down the server on any signals
        case none
        // shutdown the server if a SIGINT is received
        case sigint
        // shutdown the server if a SIGTERM is received
        case sigterm
    }
    
    private let startHandler: () throws -> ()
    private let shutdownHandler: () throws -> ()
    private let waitUntilShutdownHandler: () throws -> ()
    private let waitUntilShutdownAndThenHandler: (_ onShutdown: @escaping () -> Void) throws -> ()
    private let onShutdownHandler: (_ onShutdown: @escaping () -> Void) throws -> ()
    
    public init<HTTP1RequestHandlerType: HTTP1RequestHandler, InvocationContext: HTTP1RequestInvocationContext>(
            wrappedServer: StandardSmokeHTTP1Server<HTTP1RequestHandlerType, InvocationContext>) {
        self.startHandler = {
            try wrappedServer.start()
        }
        
        self.shutdownHandler = {
            try wrappedServer.shutdown()
        }
        
        self.waitUntilShutdownHandler = {
            try wrappedServer.waitUntilShutdown()
        }
        
        self.waitUntilShutdownAndThenHandler = { onShutdown in
            try wrappedServer.waitUntilShutdownAndThen(onShutdown: onShutdown)
        }
        
        self.onShutdownHandler = { onShutdown in
            try wrappedServer.onShutdown(onShutdown: onShutdown)
        }
    }
    
    /**
     Starts the server on the provided port. Function returns
     when the server is started. The server will continue running until
     either shutdown() is called or the surrounding application is being terminated.
     */
    public func start() throws {
        try self.startHandler()
    }
    
    /**
     Initiates the process of shutting down the server.
     */
    public func shutdown() throws {
        try self.shutdownHandler()
    }
    
    /**
     Blocks until the server has been shutdown and all completion handlers
     have been executed.
     */
    public func waitUntilShutdown() throws {
        try self.waitUntilShutdownHandler()
    }
    
    /**
     Blocks until the server has been shutdown and all completion handlers
     have been executed. The provided closure will be added to the list of
     completion handlers to be executed on shutdown. If the server is already
     shutdown, the provided closure will be immediately executed.
     
     - Parameters:
        - onShutdown: the closure to be executed after the server has been
                      fully shutdown.
     */
    public func waitUntilShutdownAndThen(onShutdown: @escaping () -> Void) throws {
        try self.waitUntilShutdownAndThenHandler(onShutdown)
    }
    
    /**
     Provides a closure to be executed after the server has been fully shutdown.
     
     - Parameters:
        - onShutdown: the closure to be executed after the server has been
                      fully shutdown.
     */
    public func onShutdown(onShutdown: @escaping () -> Void) throws {
        try self.onShutdownHandler(onShutdown)
    }
}
