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
// OperationHandler.swift
// SmokeOperations
//

import Foundation
import Logging
import SmokeInvocation
import Tracing

private let incomingOperationKey = "incomingOperation"

/**
 Struct that handles serialization and de-serialization of request and response
 bodies from and to the shapes required by operation handlers.
 */
public struct OperationHandler<ContextType, RequestHeadType, InvocationReportingType: InvocationReporting,
                               ResponseHandlerType, OperationIdentifer: OperationIdentity> {
    public typealias OperationResultValidatableInputFunction<InputType: Validatable>
        = (_ input: InputType, _ requestHead: RequestHeadType, _ context: ContextType,
        _ responseHandler: ResponseHandlerType, _ invocationContext: SmokeInvocationContext<InvocationReportingType>) -> ()
    public typealias OperationResultDataInputFunction
        = (_ requestHead: RequestHeadType, _ body: Data?, _ context: PerInvocationContext<ContextType, InvocationReportingType>,
        _ responseHandler: ResponseHandlerType, _ invocationStrategy: InvocationStrategy,
        _ requestLogger: Logger, _ internalRequestId: String, _ invocationReportingProvider: (Logger) -> InvocationReportingType) -> ()
    
    private let operationFunction: OperationResultDataInputFunction
    public let operationIdentifer: OperationIdentifer
    
    /**
     * Handle for an operation handler delegates the input to the wrapped handling function
     * constructed at initialization time.
     */
    public func handle(_ requestHead: RequestHeadType, body: Data?, withContext context: PerInvocationContext<ContextType, InvocationReportingType>,
                       responseHandler: ResponseHandlerType, invocationStrategy: InvocationStrategy,
                       requestLogger: Logger, internalRequestId: String,
                       invocationReportingProvider: @escaping (Logger) -> InvocationReportingType) {
        var decoratedRequestLogger = requestLogger
        decoratedRequestLogger[metadataKey: incomingOperationKey] = "\(self.operationIdentifer)"
        
        return operationFunction(requestHead, body, context, responseHandler,
                                 invocationStrategy, decoratedRequestLogger, internalRequestId, invocationReportingProvider)
    }
    
    private enum InputDecodeResult<InputType: Validatable> {
        case ok(input: InputType, inputHandler: OperationResultValidatableInputFunction<InputType>,
                invocationContext: SmokeInvocationContext<InvocationReportingType>)
        case error(description: String, reportableType: String?, invocationContext: SmokeInvocationContext<InvocationReportingType>)
        
        func handle<OperationDelegateType: OperationDelegate>(
                requestHead: RequestHeadType, context: PerInvocationContext<ContextType, InvocationReportingType>,
                responseHandler: ResponseHandlerType, operationDelegate: OperationDelegateType)
            where RequestHeadType == OperationDelegateType.RequestHeadType,
            InvocationReportingType == OperationDelegateType.InvocationReportingType,
            ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
            switch self {
            case .error(description: let description, reportableType: let reportableType, invocationContext: let invocationContext):
                let logger = invocationContext.invocationReporting.logger
                
                if let reportableType = reportableType {
                    withSpanContext(invocationContext: invocationContext) {
                        logger.info("DecodingError [\(reportableType): \(description)")
                    }
                } else {
                    withSpanContext(invocationContext: invocationContext) {
                        logger.info("DecodingError: \(description)")
                    }
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
                    withSpanContext(invocationContext: invocationContext) {
                        logger.info("ValidationError: \(reason)")
                    }
                    
                    operationDelegate.handleResponseForValidationError(
                        requestHead: requestHead,
                        message: reason,
                        responseHandler: responseHandler,
                        invocationContext: invocationContext)
                    return
                } catch {
                    withSpanContext(invocationContext: invocationContext) {
                        logger.info("ValidationError: \(error)")
                    }
                    
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
        
        private func withSpanContext(invocationContext: SmokeInvocationContext<InvocationReportingType>,
                                     operation: () -> ()) {
            if let span = invocationContext.invocationReporting.span {
                ServiceContext.withValue(span.context, operation: operation)
            } else {
                operation()
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
                reportingConfiguration: SmokeReportingConfiguration<OperationIdentifer>,
                operationFunction: @escaping OperationResultDataInputFunction) {
        self.operationFunction = operationFunction
        self.operationIdentifer = operationIdentifer
    }
    
    /**
     * Convenience initializer that incorporates decoding and validating
     */
    public init<InputType: Validatable, OperationDelegateType: OperationDelegate>(
        serverName: String, operationIdentifer: OperationIdentifer,
        reportingConfiguration: SmokeReportingConfiguration<OperationIdentifer>,
        inputHandler: @escaping OperationResultValidatableInputFunction<InputType>,
        inputProvider: @escaping (RequestHeadType, Data?) throws -> InputType,
        operationDelegate: OperationDelegateType, ignoreInvocationStrategy: Bool = false)
    where RequestHeadType == OperationDelegateType.RequestHeadType,
    InvocationReportingType == OperationDelegateType.InvocationReportingType,
    ResponseHandlerType == OperationDelegateType.ResponseHandlerType {
        let operationReporting = SmokeOperationReporting(serverName: serverName, request: .serverOperation(operationIdentifer),
                                                               configuration: reportingConfiguration)
        
        func getInvocationContextForAnonymousRequest(invocationReportingProvider: (Logger) -> InvocationReportingType,
                                                     requestLogger: Logger,
                                                     internalRequestId: String) -> SmokeInvocationContext<InvocationReportingType> {
            var decoratedRequestLogger: Logger = requestLogger
            operationDelegate.decorateLoggerForAnonymousRequest(requestLogger: &decoratedRequestLogger)
            
            let invocationReporting = invocationReportingProvider(decoratedRequestLogger)
            return SmokeInvocationContext(invocationReporting: invocationReporting,
                                                requestReporting: operationReporting)
        }
        
        let newFunction: OperationResultDataInputFunction = { (requestHead, body, context, responseHandler,
                                                               invocationStrategy, requestLogger, internalRequestId, invocationReportingProvider) in
            func getInvocationContextForThisAnonymousRequest() -> SmokeInvocationContext<InvocationReportingType> {
                return getInvocationContextForAnonymousRequest(invocationReportingProvider: invocationReportingProvider,
                                                               requestLogger: requestLogger, internalRequestId: internalRequestId)
            }
            
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
                
                let invocationReporting = invocationReportingProvider(decoratedRequestLogger)
                let invocationContext = SmokeInvocationContext(invocationReporting: invocationReporting,
                                                                     requestReporting: operationReporting)
                
                inputDecodeResult = .ok(input: input, inputHandler: inputHandler, invocationContext: invocationContext)
            } catch DecodingError.keyNotFound(let codingKey, let context) {
                let invocationContext = getInvocationContextForThisAnonymousRequest()
                
                let codingPath = context.codingPath + [codingKey]
                let description = "Key not found \(codingPath.pathDescription)."
                inputDecodeResult = .error(description: description, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.valueNotFound(_, let context) {
                let invocationContext = getInvocationContextForThisAnonymousRequest()
                
                let description = "Required value not found \(context.codingPath.pathDescription)."
                inputDecodeResult = .error(description: description, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.typeMismatch(let expectedType, let context) {
                let invocationContext = getInvocationContextForThisAnonymousRequest()
                
                // Special case for a dictionary, return as "Structure"
                let expectedTypeString = (expectedType == [String: Any].self) ? "Structure" : String(describing: expectedType)
                let description = "Incorrect type \(context.codingPath.pathDescription). Expected \(expectedTypeString)."
                inputDecodeResult = .error(description: description, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch DecodingError.dataCorrupted(let context) {
                let invocationContext = getInvocationContextForThisAnonymousRequest()
                
                inputDecodeResult = .error(description: context.dataCorruptionPathDescription, reportableType: nil,
                                           invocationContext: invocationContext)
            } catch SmokeOperationsError.validationError(reason: let reason) {
                let invocationContext = getInvocationContextForThisAnonymousRequest()

                inputDecodeResult = .error(description: reason, reportableType: "SmokeOperationsError",
                                           invocationContext: invocationContext)
            } catch {
                let invocationContext = getInvocationContextForThisAnonymousRequest()
                
                let errorType = type(of: error)
                inputDecodeResult = .error(description: "\(error)", reportableType: "\(errorType)",
                                           invocationContext: invocationContext)
            }
            
            // continue the execution of the request according to the `invocationStrategy`
            // To avoid retaining the original body `Data` object, `body` should not be referenced in this
            // invocation.
            if ignoreInvocationStrategy {
                inputDecodeResult.handle(requestHead: requestHead, context: context,
                    responseHandler: responseHandler, operationDelegate: operationDelegate)
            } else {
                invocationStrategy.invoke {
                    inputDecodeResult.handle(requestHead: requestHead, context: context,
                        responseHandler: responseHandler, operationDelegate: operationDelegate)
                }
            }
        }
        
        self.operationFunction = newFunction
        self.operationIdentifer = operationIdentifer
    }
    
    public static func withSpanContext(invocationContext: SmokeInvocationContext<InvocationReportingType>,
                                       operation: () async -> ()) async {
        if let span = invocationContext.invocationReporting.span {
            await ServiceContext.withValue(span.context, operation: operation)
        } else {
            await operation()
        }
    }
}

private extension DecodingError.Context {
    var dataCorruptionPathDescription: String {
        if self.codingPath.isEmpty {
            // the data provided is not valid input
            return self.debugDescription
        } else {
            return "Data corrupted \(self.codingPath.pathDescription). \(self.debugDescription)."
        }
    }
}

private extension Array where Element == CodingKey {
    var pathDescription: String {
        if self.isEmpty {
            return "at base of structure"
        }
        return "at path '\(self.stringRepresentation)'"
    }
    
    var stringRepresentation: String {
        let initialValue: ([CodingPathSegment], CodingPathSegment?) = ([], nil)
        let finalValue = self.reduce(initialValue) { partialResult, codingKey in
            let keyType = codingKey.type
            
            switch keyType {
            case .attribute(let attribute):
                let updatedPastSegments: [CodingPathSegment]
                if let currentSegment = partialResult.1 {
                    updatedPastSegments = partialResult.0 + [currentSegment]
                } else {
                    updatedPastSegments = partialResult.0
                }
                
                // create a new path segment
                return (updatedPastSegments, CodingPathSegment(attribute: attribute))
            case .index(let index):
                var updatedPathSegment = partialResult.1 ?? CodingPathSegment()
                updatedPathSegment.indicies.append(index)
                
                // update the current path segment
                return (partialResult.0, updatedPathSegment)
            }
        }

        let segments: [CodingPathSegment]
        if let currentSegment = finalValue.1 {
            segments = finalValue.0 + [currentSegment]
        } else {
            segments = finalValue.0
        }
        
        return segments.map { $0.stringRepresentation }.joined(separator: ".")
    }
}

private enum CodingKeyType {
    case attribute(String)
    case index(Int)
}

private struct CodingPathSegment {
    let attribute: String?
    var indicies: [Int]
    
    init(attribute: String? = nil, indicies: [Int] = []) {
        self.attribute = attribute
        self.indicies = indicies
    }
    
    var stringRepresentation: String {
        let indiciesRepresentation = self.indicies.map { "[\($0)]"}.joined()
        
        if let attribute = self.attribute {
            return "\(attribute)\(indiciesRepresentation)"
        } else {
            return indiciesRepresentation
        }
    }
}

private extension CodingKey {
    var type: CodingKeyType {
        if let intValue = self.intValue {
            return .index(intValue)
        }
        
        return .attribute(self.stringValue)
    }
}
