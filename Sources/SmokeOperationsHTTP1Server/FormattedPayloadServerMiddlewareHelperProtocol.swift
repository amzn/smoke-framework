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
//  FormattedPayloadServerMiddlewareHelperProtocol.swift
//  SmokeOperationsHTTP1Server
//

import SwiftMiddleware
import NIOHTTP1
import SmokeAsyncHTTP1Server
import SmokeOperations
import SmokeOperationsHTTP1

internal struct EmptyMiddleware<Input, OutputWriter, Context>: MiddlewareProtocol {
    public func handle(_ input: Input,
                       outputWriter: OutputWriter,
                       context: Context,
                       next: (Input, OutputWriter, Context) async throws -> Void) async throws {
        try await next(input, outputWriter, context)
    }
}

public protocol FormattedPayloadServerMiddlewareHelperProtocol {
    associatedtype MiddlewareStackType: ServerMiddlewareStackProtocol
    associatedtype ApplicationContextType
    
    typealias RouterType = MiddlewareStackType.RouterType
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack and the request and response transforms specified by this type.
     Operation handler provides an input and an output.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response status to use for a success payload.
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type.
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, InnerMiddlewareType.OutputWriter, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack and the request and response transforms specified by this type.
     Operation handler provides an input and no output.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response status to use for a success payload.
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type.
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType == Void
    
    /**
     Adds a handler for the specified uri and http method using this middleware stack and the request and response transforms specified by this type.
     Operation handler provides no input and an output.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - allowedErrors: The errors that have been identified as being returned by the operation
        - statusOnSuccess: The response status to use for a success payload.
        - operation: the operation handler to add.
        - outerMiddleware: The middleware stack that is called prior to the transformation into the operation's input type.
        - innerMiddleware: The middleware stack that is called after to the transformation into the operation's input type.
     */
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.OutputWriter.OutputType,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol
}

public extension FormattedPayloadServerMiddlewareHelperProtocol {
    //-- Input and Output
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, InnerMiddlewareType.OutputWriter, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, VoidResponseWriter, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<Input, Output, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (Input, ApplicationContextType) async throws -> Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    Input: OperationHTTP1InputProtocol, Output: OperationHTTP1OutputProtocol {
        let innerMiddleware: EmptyMiddleware<Input, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<Input, Output, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (Input, ApplicationContextType) async throws -> Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType)
    where Input: OperationHTTP1InputProtocol, Output: OperationHTTP1OutputProtocol {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Input, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    //-- Input and no Output
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (InnerMiddlewareType.Input, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType == Void {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<Input, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (Input, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    Input: OperationHTTP1InputProtocol {
        let innerMiddleware: EmptyMiddleware<Input, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<Input, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (Input, ApplicationContextType) async throws -> (),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType)
    where Input: OperationHTTP1InputProtocol {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Input, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    //-- No Input and with Output
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperation<InnerMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> InnerMiddlewareType.Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperation<Output, OuterMiddlewareType: MiddlewareProtocol,
                                         ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    Output: OperationHTTP1OutputProtocol {
        let innerMiddleware: EmptyMiddleware<Void, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperation<Output, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operation: @escaping @Sendable (ApplicationContextType) async throws -> Output,
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType)
    where Output: OperationHTTP1OutputProtocol {
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Void, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: operation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    //-- Input and Output
    
    // -- Inner and Outer Middleware
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (InnerMiddlewareType.Input) async throws -> InnerMiddlewareType.Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            let operation = operationProvider(context)
            return try await operation(input)
        }
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (InnerMiddlewareType.Input) async throws -> InnerMiddlewareType.Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            let operation = operationProvider(context)
            return try await operation(input)
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperationProvider<Input, Output, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (Input) async throws -> Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    Input: OperationHTTP1InputProtocol, Output: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(input: Input, context: ApplicationContextType) async throws -> Output {
            let operation = operationProvider(context)
            return try await operation(input)
        }
        
        let innerMiddleware: EmptyMiddleware<Input, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperationProvider<Input, Output, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (Input) async throws -> Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType)
    where Input: OperationHTTP1InputProtocol, Output: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(input: Input, context: ApplicationContextType) async throws -> Output {
            let operation = operationProvider(context)
            return try await operation(input)
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Input, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    //-- Input and no Output
    
    // -- Inner and Outer Middleware
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (InnerMiddlewareType.Input) async throws -> Void),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType == Void {
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            try await operation(input)
        }
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (InnerMiddlewareType.Input) async throws -> Void),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input: OperationHTTP1InputProtocol, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType == Void {
        @Sendable func innerOperation(input: InnerMiddlewareType.Input, context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            try await operation(input)
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperationProvider<Input, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (Input) async throws -> Void),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    Input: OperationHTTP1InputProtocol {
        @Sendable func innerOperation(input: Input, context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            try await operation(input)
        }
        
        let innerMiddleware: EmptyMiddleware<Input, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperationProvider<Input, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable (Input) async throws -> Void),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType)
    where Input: OperationHTTP1InputProtocol {
        @Sendable func innerOperation(input: Input, context: ApplicationContextType) async throws {
            let operation = operationProvider(context)
            try await operation(input)
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Input, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    //-- No Input and with Output
    
    // -- Inner and Outer Middleware
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext, OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- Inner and no Outer Middleware
    mutating func addHandlerForOperationProvider<InnerMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> InnerMiddlewareType.Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        innerMiddleware: InnerMiddlewareType?)
    where InnerMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    InnerMiddlewareType.Input == Void, InnerMiddlewareType.OutputWriter: TypedOutputWriterProtocol,
    InnerMiddlewareType.OutputWriter.OutputType: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(context: ApplicationContextType) async throws -> InnerMiddlewareType.Output {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and with Outer Middleware
    mutating func addHandlerForOperationProvider<Output, OuterMiddlewareType: MiddlewareProtocol,
                                                 ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType,
        outerMiddleware: OuterMiddlewareType?)
    where OuterMiddlewareType.Input == HTTPServerRequest, OuterMiddlewareType.OutputWriter: HTTPServerResponseWriterProtocol,
    OuterMiddlewareType.Context == RouterType.IncomingMiddlewareContext,
    Output: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(context: ApplicationContextType) async throws -> Output {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let innerMiddleware: EmptyMiddleware<Void, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
    
    // -- No Inner and no Outer Middleware
    mutating func addHandlerForOperationProvider<Output, ErrorType: ErrorIdentifiableByDescription>(
        _ operationIdentifer: RouterType.OperationIdentifer, httpMethod: HTTPMethod,
        operationProvider: @escaping (ApplicationContextType) -> (@Sendable () async throws -> Output),
        allowedErrors: [(ErrorType, Int)], statusOnSuccess: HTTPResponseStatus, toStack middlewareStack: inout MiddlewareStackType)
    where Output: OperationHTTP1OutputProtocol {
        @Sendable func innerOperation(context: ApplicationContextType) async throws -> Output {
            let operation = operationProvider(context)
            return try await operation()
        }
        
        let outerMiddleware: EmptyMiddleware<HTTPServerRequest, Void, RouterType.IncomingMiddlewareContext>? = nil
        let innerMiddleware: EmptyMiddleware<Void, Output, RouterType.IncomingMiddlewareContext>? = nil
        
        return self.addHandlerForOperation(operationIdentifer, httpMethod: httpMethod, operation: innerOperation,
                                           allowedErrors: allowedErrors, statusOnSuccess: statusOnSuccess, toStack: &middlewareStack,
                                           outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware)
    }
}

