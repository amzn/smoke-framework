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
// OperationHandler.swift
// SmokeOperations
//

import Foundation
import Logging
import SmokeInvocation

/**
 Struct that handles serialization and de-serialization of request and response
 bodies from and to the shapes required by operation handlers.
 */
public struct OperationHandler<ContextType, RequestHeadType, TraceContextType: OperationTraceContext,
                               ResponseHandlerType, OperationIdentifer: OperationIdentity> {
    public typealias OperationResultValidatableInputFunction<InputType: Validatable>
        = (_ input: InputType, _ requestHead: RequestHeadType, _ context: ContextType,
        _ responseHandler: ResponseHandlerType, _ invocationContext: SmokeServerInvocationContext<TraceContextType>) -> ()
    public typealias OperationResultDataInputFunction
        = (_ requestHead: RequestHeadType, _ body: Data?, _ context: PerInvocationContext<ContextType, TraceContextType>,
        _ responseHandler: ResponseHandlerType, _ invocationStrategy: InvocationStrategy,
        _ requestLogger: Logger, _ internalRequestId: String, _ traceContext: TraceContextType) -> ()
    
    private let operationFunction: OperationResultDataInputFunction
    
    /**
     * Handle for an operation handler delegates the input to the wrapped handling function
     * constructed at initialization time.
     */
    public func handle(_ requestHead: RequestHeadType, body: Data?, withContext context: PerInvocationContext<ContextType, TraceContextType>,
                       responseHandler: ResponseHandlerType, invocationStrategy: InvocationStrategy,
                       requestLogger: Logger, internalRequestId: String, traceContext: TraceContextType) {
        return operationFunction(requestHead, body, context, responseHandler,
                                 invocationStrategy, requestLogger, internalRequestId, traceContext)
    }
    
    private enum InputDecodeResult<InputType: Validatable> {
        case ok(input: InputType, inputHandler: OperationResultValidatableInputFunction<InputType>,
                invocationContext: SmokeServerInvocationContext<TraceContextType>)
        case error(description: String, reportableType: String?, invocationContext: SmokeServerInvocationContext<TraceContextType>)
        
        func handle<OperationDelegateType: OperationDelegate>(
                requestHead: RequestHeadType, context: PerInvocationContext<ContextType, TraceContextType>,
                responseHandler: ResponseHandlerType, operationDelegate: OperationDelegateType)
            where RequestHeadType == OperationDelegateType.RequestHeadType,
            TraceContextType == OperationDelegateType.TraceContextType,
            ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            switch self {
            case .error(description: let description, reportableType: let reportableType, invocationContext: let invocationContext):
                let logger = invocationContext.invocationReporting.logger
                
                if let reportableType = reportableType {
                    logger.error("DecodingError [\(reportableType): \(description)")
                } else {
                    logger.error("DecodingError: \(description)")
                }
                
                operationDelegate.handleResponseForDecodingError(
                    requestHead: requestHead,
                    message: description,
                    responseHandler: responseHandler, invocationContext: invocationContext)
            case .ok(input: let input, inputHandler: let inputHandler, invocationContext: let invocationContext):
                let logger = invocationContext.invocationReporting.logger
                
                do {
                    // attempt to validate the input
                    try input.validate()
                } catch SmokeOperationsError.validationError(let reason) {
                    logger.warning("ValidationError: \(reason)")
                    
                    operationDelegate.handleResponseForValidationError(
                        requestHead: requestHead,
                        message: reason,
                        responseHandler: responseHandler,
                        invocationContext: invocationContext)
                    return
                } catch {
                    logger.warning("ValidationError: \(error)")
                    
                    operationDelegate.handleResponseForValidationError(
                        requestHead: requestHead,
                        message: nil,
                        responseHandler: responseHandler,
                        invocationContext: invocationContext)
                    return
                }
                
                let contextForInvocation: ContextType
                switch context {
                case .static(let staticContext):
                    contextForInvocation = staticContext
                case .provider(let contextProvider):
                    contextForInvocation = contextProvider(invocationContext.invocationReporting)
                }
                
                inputHandler(input, requestHead, contextForInvocation, responseHandler, invocationContext)
            }
        }
    }
    
    /**
     Initialier that accepts the function to use to handle this operation.
 
     - Parameters:
        - serverName: the name of the server this operation is part of.
        - operationIdentifer: the identifer for the operation being handled.
        - reportingConfiguration: the configuration for how operations on this server should be reported on.
        - operationFunction: the function to use to handle this operation.
     */
    public init(serverName: String, operationIdentifer: OperationIdentifer,
                reportingConfiguration: SmokeServerReportingConfiguration<OperationIdentifer>,
                operationFunction: @escaping OperationResultDataInputFunction) {
        self.operationFunction = operationFunction
    }
    
    /**
     * Convenience initializer that incorporates decoding and validating
     */
    public init<InputType: Validatable, OperationDelegateType: OperationDelegate>(
        serverName: String, operationIdentifer: OperationIdentifer,
        reportingConfiguration: SmokeServerReportingConfiguration<OperationIdentifer>,
        inputHandler: @escaping OperationResultValidatableInputFunction<InputType>,
        inputProvider: @escaping (RequestHeadType, Data?) throws -> InputType,
        operationDelegate: OperationDelegateType)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    TraceContextType == OperationDelegateType.TraceContextType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        let operationReporting = SmokeServerOperationReporting(serverName: serverName, request: .serverOperation(operationIdentifer),
                                                               configuration: reportingConfiguration)
        
        func getInvocationContextForAnonymousRequest(traceContext: TraceContextType,
                                                     requestLogger: Logger,
                                                     internalRequestId: String) -> SmokeServerInvocationContext<TraceContextType> {
            var decoratedRequestLogger: Logger = requestLogger
            operationDelegate.decorateLoggerForAnonymousRequest(requestLogger: &decoratedRequestLogger)
            
            let invocationReporting = SmokeServerInvocationReporting(logger: decoratedRequestLogger,
                                                                     internalRequestId: internalRequestId, traceContext: traceContext)
            return SmokeServerInvocationContext(invocationReporting: invocationReporting,
                                                requestReporting: operationReporting)
        }
        
        let newFunction: OperationResultDataInputFunction = { (requestHead, body, context, responseHandler,
                                                               invocationStrategy, requestLogger, internalRequestId, traceContext) in
            let inputDecodeResult: InputDecodeResult<InputType>
            do {
                // decode the response within the event loop of the server to limit the number of request
                // `Data` objects that exist at single time to the number of threads in the event loop
                let input: InputType = try inputProvider(requestHead, body)
                
                // if the input can decorate the request logger
                var decoratedRequestLogger: Logger = requestLogger
                if let requestLoggerDecorator = input as? RequestLoggerDecorator {
                    requestLoggerDecorator.decorate(requestLogger: &decoratedRequestLogger)
                }
                
                let invocationReporting = SmokeServerInvocationReporting(logger: decoratedRequestLogger,
                                                                         internalRequestId: internalRequestId, traceContext: traceContext)
                let invocationContext = SmokeServerInvocationContext(invocationReporting: invocationReporting,
                                                                     requestReporting: operationReporting)
                
                inputDecodeResult = .ok(input: input, inputHandler: inputHandler, invocationContext: invocationContext)
            } catch DecodingError.keyNotFound(_, let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(traceContext: traceContext,
                                                                                requestLogger: requestLogger,
                                                                                internalRequestId: internalRequestId)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.valueNotFound(_, let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(traceContext: traceContext,
                                                                                requestLogger: requestLogger,
                                                                                internalRequestId: internalRequestId)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.typeMismatch(_, let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(traceContext: traceContext,
                                                                                requestLogger: requestLogger,
                                                                                internalRequestId: internalRequestId)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.dataCorrupted(let context) {
                let invocationContext = getInvocationContextForAnonymousRequest(traceContext: traceContext,
                                                                                requestLogger: requestLogger,
                                                                                internalRequestId: internalRequestId)
                inputDecodeResult = .error(description: context.debugDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch {
                let invocationContext = getInvocationContextForAnonymousRequest(traceContext: traceContext,
                                                                                requestLogger: requestLogger,
                                                                                internalRequestId: internalRequestId)
                let errorType = type(of: error)
                inputDecodeResult = .error(description: "\(error)", reportableType: "\(errorType)",
                                           invocationContext: invocationContext)
            }
            
            // continue the execution of the request according to the `invocationStrategy`
            // To avoid retaining the original body `Data` object, `body` should not be referenced in this
            // invocation.
            invocationStrategy.invoke {
                inputDecodeResult.handle(
                    requestHead: requestHead,
                    context: context,
                    responseHandler: responseHandler,
                    operationDelegate: operationDelegate)
            }
        }
        
        self.operationFunction = newFunction
    }
}
