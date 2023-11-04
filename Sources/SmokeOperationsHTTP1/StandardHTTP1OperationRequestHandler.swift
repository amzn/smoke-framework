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
// StandardHTTP1OperationRequestHandler.swift
// SmokeOperationsHTTP1
//
import Foundation
import Logging
import NIOHTTP1
import ShapeCoding
import SmokeInvocation
import SmokeOperations

internal enum PingParameters {
    static let uri = "/ping"
    static let payload = "Ping completed.".data(using: .utf8) ?? Data()
}

public enum RequestExecutor {
    case originalEventLoop
    case cooperativeTaskGroup
    case dispatchQueue
}

/**
 Implementation of the HttpRequestHandler protocol that handles an
 incoming Http request as an operation.
 */
public struct StandardHTTP1OperationRequestHandler<SelectorType>: HTTP1OperationRequestHandler
    where SelectorType: SmokeHTTP1HandlerSelector,
    SmokeHTTP1RequestHead == SelectorType.DefaultOperationDelegateType.RequestHeadType,
    SelectorType.DefaultOperationDelegateType.ResponseHandlerType: HTTP1ResponseHandler,
    SmokeInvocationContext<SelectorType.DefaultOperationDelegateType.InvocationReportingType> == SelectorType.DefaultOperationDelegateType.ResponseHandlerType
        .InvocationContext {
    public typealias ResponseHandlerType = SelectorType.DefaultOperationDelegateType.ResponseHandlerType

    // The providers that are used to delay some actions
    public struct Actions {
        // used to instantiate invocationReporting from a decorated logger
        public let invocationReportingProvider: (Logger) -> InvocationReportingType
        // used to call `handleInwardsRequestStart` on the trace context after ping requests have been handled
        public let requestStartTraceAction: (() -> (Logger))?

        public init(invocationReportingProvider: @escaping (Logger) -> InvocationReportingType,
                    requestStartTraceAction: (() -> (Logger))?) {
            self.invocationReportingProvider = invocationReportingProvider
            self.requestStartTraceAction = requestStartTraceAction
        }
    }

    typealias InvocationContext = ResponseHandlerType.InvocationContext
    public typealias InvocationReportingType = SelectorType.DefaultOperationDelegateType.InvocationReportingType

    let handlerSelector: SelectorType
    let context: PerInvocationContext<SelectorType.ContextType, InvocationReportingType>
    let pingOperationReporting: SmokeOperationReporting
    let unknownOperationReporting: SmokeOperationReporting
    let errorDeterminingOperationReporting: SmokeOperationReporting
    let requestExecutor: RequestExecutor
    let enableTracingWithSwiftConcurrency: Bool

    public init(handlerSelector: SelectorType, context: SelectorType.ContextType, serverName: String,
                reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>,
                requestExecutor: RequestExecutor = .originalEventLoop,
                enableTracingWithSwiftConcurrency: Bool = false) {
        self.handlerSelector = handlerSelector
        self.context = .static(context)

        self.pingOperationReporting = SmokeOperationReporting(serverName: serverName, request: .ping,
                                                              configuration: reportingConfiguration)
        self.unknownOperationReporting = SmokeOperationReporting(serverName: serverName, request: .unknownOperation,
                                                                 configuration: reportingConfiguration)
        self.errorDeterminingOperationReporting = SmokeOperationReporting(serverName: serverName,
                                                                          request: .errorDeterminingOperation,
                                                                          configuration: reportingConfiguration)
        self.requestExecutor = requestExecutor
        self.enableTracingWithSwiftConcurrency = enableTracingWithSwiftConcurrency
    }

    public init(handlerSelector: SelectorType,
                contextProvider: @escaping (InvocationReportingType) -> SelectorType.ContextType,
                serverName: String, reportingConfiguration: SmokeReportingConfiguration<SelectorType.OperationIdentifer>,
                requestExecutor: RequestExecutor = .originalEventLoop,
                enableTracingWithSwiftConcurrency: Bool = false) {
        self.handlerSelector = handlerSelector
        self.context = .provider(contextProvider)

        self.pingOperationReporting = SmokeOperationReporting(serverName: serverName, request: .ping,
                                                              configuration: reportingConfiguration)
        self.unknownOperationReporting = SmokeOperationReporting(serverName: serverName, request: .unknownOperation,
                                                                 configuration: reportingConfiguration)
        self.errorDeterminingOperationReporting = SmokeOperationReporting(serverName: serverName,
                                                                          request: .errorDeterminingOperation,
                                                                          configuration: reportingConfiguration)
        self.requestExecutor = requestExecutor
        self.enableTracingWithSwiftConcurrency = enableTracingWithSwiftConcurrency
    }

    private func getInvocationContextForAnonymousRequest(requestReporting: SmokeOperationReporting,
                                                         requestLogger: Logger,
                                                         invocationReportingProvider: @escaping (Logger) -> InvocationReportingType)
    -> SmokeInvocationContext<InvocationReportingType> {
        var decoratedRequestLogger: Logger = requestLogger
        self.handlerSelector.defaultOperationDelegate.decorateLoggerForAnonymousRequest(requestLogger: &decoratedRequestLogger)

        let invocationReporting = invocationReportingProvider(decoratedRequestLogger)
        return SmokeInvocationContext(invocationReporting: invocationReporting,
                                      requestReporting: requestReporting)
    }

    /**
     The original handle method, retained for backwards compatibility.
     The `invocationReportingProvider` is a workaround to construct the InvocationReporting
     instance from an appropriately decorated `Logger`.
     */
    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                       invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String,
                       invocationReportingProvider: @escaping (Logger) -> InvocationReportingType) {
        let actions = Actions(invocationReportingProvider: invocationReportingProvider, requestStartTraceAction: nil)

        self.handleForActionsProvider(requestHead: requestHead, body: body, responseHandler: responseHandler,
                                      invocationStrategy: invocationStrategy, requestLogger: requestLogger,
                                      internalRequestId: internalRequestId, actionsProvider: { _ in actions })
    }

    /**
     An updated handle method but now also retained for backwards compatibility.
     The `invocationReportingProvider` is a workaround to construct the InvocationReporting
     instance from an appropriately decorated `Logger`.
     The `requestStartTraceAction` is a workaround to call `handleInwardsRequestStart` on the
     trace context after ping requests have been handled
     */
    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                       invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String,
                       invocationReportingProvider: @escaping (Logger) -> InvocationReportingType,
                       requestStartTraceAction: (() -> (Logger))?) {
        let actions = Actions(invocationReportingProvider: invocationReportingProvider,
                              requestStartTraceAction: requestStartTraceAction)

        self.handleForActionsProvider(requestHead: requestHead, body: body, responseHandler: responseHandler,
                                      invocationStrategy: invocationStrategy, requestLogger: requestLogger,
                                      internalRequestId: internalRequestId, actionsProvider: { _ in actions })
    }

    /**
     The currently used handle method where actions can be created based on a provided options instance.
     */
    public func handle(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                       invocationStrategy: InvocationStrategy, requestLogger: Logger, internalRequestId: String,
                       actionsProvider: @escaping (OperationTraceContextOptions?) -> Actions) {
        self.handleForActionsProvider(requestHead: requestHead, body: body, responseHandler: responseHandler,
                                      invocationStrategy: invocationStrategy, requestLogger: requestLogger,
                                      internalRequestId: internalRequestId, actionsProvider: actionsProvider)
    }

    private func handleForActionsProvider(requestHead: HTTPRequestHead, body: Data?,
                                          responseHandler: ResponseHandlerType,
                                          invocationStrategy: InvocationStrategy,
                                          requestLogger: Logger, internalRequestId: String,
                                          actionsProvider: @escaping (OperationTraceContextOptions?) -> Actions) {
        // this is the ping url
        if requestHead.uri == PingParameters.uri {
            let body = (contentType: "text/plain", data: PingParameters.payload)
            let actions = actionsProvider(nil)
            let responseComponents = HTTP1ServerResponseComponents(additionalHeaders: [], body: body)
            let invocationContext = self.getInvocationContextForAnonymousRequest(
                requestReporting: self.pingOperationReporting,
                requestLogger: requestLogger,
                invocationReportingProvider: actions.invocationReportingProvider)
            responseHandler.completeSilentlyInEventLoop(invocationContext: invocationContext,
                                                        status: .ok, responseComponents: responseComponents)

            return
        }

        switch self.requestExecutor {
            case .cooperativeTaskGroup:
                Task {
                    handleOnDesiredThreadPool(requestHead: requestHead, body: body, responseHandler: responseHandler,
                                              invocationStrategy: invocationStrategy, requestLogger: requestLogger,
                                              internalRequestId: internalRequestId, actionsProvider: actionsProvider)
                }
            case .dispatchQueue:
                DispatchQueue.global().async {
                    handleOnDesiredThreadPool(requestHead: requestHead, body: body, responseHandler: responseHandler,
                                              invocationStrategy: invocationStrategy, requestLogger: requestLogger,
                                              internalRequestId: internalRequestId, actionsProvider: actionsProvider)
                }
            case .originalEventLoop:
                self.handleOnDesiredThreadPool(requestHead: requestHead, body: body, responseHandler: responseHandler,
                                               invocationStrategy: invocationStrategy, requestLogger: requestLogger,
                                               internalRequestId: internalRequestId, actionsProvider: actionsProvider)
        }
    }

    private func handleOnDesiredThreadPool(requestHead: HTTPRequestHead, body: Data?, responseHandler: ResponseHandlerType,
                                           invocationStrategy: InvocationStrategy, requestLogger originalLogger: Logger,
                                           internalRequestId: String,
                                           actionsProvider: (OperationTraceContextOptions?) -> Actions) {
        let uriComponents = requestHead.uri.split(separator: "?", maxSplits: 1)
        let path = String(uriComponents[0])
        let query = uriComponents.count > 1 ? String(uriComponents[1]) : ""

        // get the handler to use
        let handler: OperationHandler<SelectorType.ContextType, SmokeHTTP1RequestHead, InvocationReportingType,
            ResponseHandlerType, SelectorType.OperationIdentifer>
        let shape: Shape
        let defaultOperationDelegate = self.handlerSelector.defaultOperationDelegate

        do {
            (handler, shape) = try self.handlerSelector.getHandlerForOperation(
                path,
                httpMethod: requestHead.method, requestLogger: originalLogger)
        } catch SmokeOperationsError.invalidOperation(reason: let reason) {
            let smokeHTTP1RequestHead = SmokeHTTP1RequestHead(httpRequestHead: requestHead,
                                                              query: query,
                                                              pathShape: .null)

            let tracingOptions = getTracingOptions(for: "InvalidOperation", internalRequestId: internalRequestId)
            let actions = actionsProvider(tracingOptions)
            let requestLogger = actions.requestStartTraceAction?() ?? originalLogger

            let invocationContext = getInvocationContextForAnonymousRequest(
                requestReporting: unknownOperationReporting,
                requestLogger: requestLogger,
                invocationReportingProvider: actions.invocationReportingProvider)
            defaultOperationDelegate.handleResponseForInvalidOperation(
                requestHead: smokeHTTP1RequestHead,
                message: reason,
                responseHandler: responseHandler,
                invocationContext: invocationContext)
            return
        } catch {
            let tracingOptions = self.getTracingOptions(for: "FailedHandlerSelection", internalRequestId: internalRequestId)
            let actions = actionsProvider(tracingOptions)
            let requestLogger = actions.requestStartTraceAction?() ?? originalLogger

            requestLogger.error("Unexpected handler selection error.",
                                metadata: ["cause": "\(String(describing: error))"])
            let smokeHTTP1RequestHead = SmokeHTTP1RequestHead(httpRequestHead: requestHead,
                                                              query: query,
                                                              pathShape: .null)

            let invocationContext = self.getInvocationContextForAnonymousRequest(
                requestReporting: self.errorDeterminingOperationReporting,
                requestLogger: requestLogger,
                invocationReportingProvider: actions.invocationReportingProvider)
            defaultOperationDelegate.handleResponseForInternalServerError(
                requestHead: smokeHTTP1RequestHead,
                responseHandler: responseHandler,
                invocationContext: invocationContext)
            return
        }

        let smokeHTTP1RequestHead = SmokeHTTP1RequestHead(httpRequestHead: requestHead,
                                                          query: query,
                                                          pathShape: shape)

        let tracingOptions = self.getTracingOptions(for: handler.operationIdentifer.description, 
                                                    internalRequestId: internalRequestId)
        let actions = actionsProvider(tracingOptions)
        let requestLogger = actions.requestStartTraceAction?() ?? originalLogger

        // let it be handled
        handler.handle(smokeHTTP1RequestHead, body: body, withContext: self.context,
                       responseHandler: responseHandler, invocationStrategy: invocationStrategy,
                       requestLogger: requestLogger, internalRequestId: internalRequestId,
                       invocationReportingProvider: actions.invocationReportingProvider)
    }

    private func getTracingOptions(for operationName: String, internalRequestId: String)
    -> OperationTraceContextOptions {
        let createRequestSpan: CreateRequestSpan
        if self.enableTracingWithSwiftConcurrency {
            let parameters = RequestSpanParameters(operationName: operationName, internalRequestId: internalRequestId)
            createRequestSpan = .ifRequired(parameters)
        } else {
            createRequestSpan = .never
        }

        return .init(createRequestSpan: createRequestSpan)
    }
}
