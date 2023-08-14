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
//  SmokeInvocationTraceContext.swift
//  SmokeOperationsHTTP1
//
import Foundation
import Logging
import SmokeHTTPClient
import SmokeOperations
import NIOHTTP1
import AsyncHTTPClient
import Tracing

private enum OperationFailure: Error {
    case withResponseBody(String)
    case withNoResponseBody
}

private extension Data {
    var debugString: String {
        return String(data: self, encoding: .utf8) ?? ""
    }
}

private extension Optional where Wrapped == Data {
    var debugString: String {
        switch self {
        case .some(let wrapped):
            return wrapped.debugString
        case .none:
            return ""
        }
    }
}

private let requestIdHeader = "x-smoke-request-id"
private let traceIdHeader = "x-smoke-trace-id"

/**
  A  type conforming to both the `HTTP1OperationTraceContext` and `InvocationTraceContext` protocols providing basic logging and tracing.
 */
public struct SmokeInvocationTraceContext {
    private let externalRequestId: String?
    private let traceId: String?
    
    private let parentSpan: Span?
    public let span: Span?
    
    public init(externalRequestId: String? = nil,
                traceId: String? = nil,
                parentSpan: Span? = nil,
                span: Span? = nil) {
        self.externalRequestId = externalRequestId
        self.traceId = traceId
        self.parentSpan = parentSpan
        self.span = span
    }
}

extension SmokeInvocationTraceContext: OperationTraceContext {
    public init(requestHead: HTTPRequestHead, bodyData: Data?) {
        self.init(requestHead: requestHead, bodyData: bodyData, options: nil)
    }
    
    public init(requestHead: NIOHTTP1.HTTPRequestHead, bodyData: Data?, options: OperationTraceContextOptions?) {
        let requestIds = requestHead.headers[requestIdHeader]
        let traceIds = requestHead.headers[traceIdHeader]
        
        // get the request id if present
        if !requestIds.isEmpty {
            let joinedExternalRequestId = requestIds.joined(separator: ",")
            
            if joinedExternalRequestId != "none" {
                self.externalRequestId = joinedExternalRequestId
            } else {
                self.externalRequestId = nil
            }
        } else {
            self.externalRequestId = nil
        }
        
        // get the trace id if present
        if !traceIds.isEmpty {
            let joinedTraceId = traceIds.joined(separator: ",")
            
            if joinedTraceId != "none" {
                self.traceId = joinedTraceId
            } else {
                self.traceId = nil
            }
        } else {
            self.traceId = nil
        }
        
#if swift(>=5.7.0)
        if case .ifRequired(let parameters) = options?.createRequestSpan {
            var serviceContext = ServiceContext.current ?? .topLevel
            let operationName = parameters.operationName
            InstrumentationSystem.instrument.extract(requestHead.headers, into: &serviceContext, using: HTTPHeadersExtractor())
            
            let parentSpan = InstrumentationSystem.tracer.startSpan("ServerRequest", context: serviceContext, ofKind: .server)
            
            var attributes: SpanAttributes = [:]
            
            attributes["http.method"] = requestHead.method.rawValue
            attributes["http.target"] = requestHead.uri
            attributes["http.flavor"] = "\(requestHead.version.major).\(requestHead.version.minor)"
            attributes["http.user_agent"] = requestHead.headers.first(name: "user-agent")
            attributes["http.request_content_length"] = requestHead.headers.first(name: "content-length")
            
            parentSpan.attributes = attributes
            
            self.parentSpan = parentSpan
            
            self.span = InstrumentationSystem.tracer.startSpan(operationName, context: parentSpan.context)
        } else {
            self.parentSpan = nil
            self.span = nil
        }
#else
        self.parentSpan = nil
        self.span = nil
#endif
    }
    
    public func handleInwardsRequestStart(requestHead: HTTPRequestHead, bodyData: Data?, logger: inout Logger, internalRequestId: String) {
        var logMetadata: Logger.Metadata = ["method": "\(requestHead.method)",
                                            "uri": "\(requestHead.uri)"]
        
        if let externalRequestId = self.externalRequestId {
            logger[metadataKey: requestIdHeader] = "\(externalRequestId)"
        }
        
        if let traceId = self.traceId {
            logger[metadataKey: traceIdHeader] = "\(traceId)"
        }
        
        if let bodyData = bodyData {
            logMetadata["bodyBytesCount"] = "\(bodyData.count)"
            logMetadata["bodyData"] = "\(bodyData.debugString)"
        }
        
        func logIncomingRequest() {
            // log details about the incoming request
            logger.info("Incoming request received.", metadata: logMetadata)
        }
        
        if let span = self.span {
            span.attributes["smoke.internalRequestId"] = internalRequestId
            
            ServiceContext.withValue(span.context, operation: logIncomingRequest)
        } else {
            logIncomingRequest()
        }
    }
    
    public func handleInwardsRequestComplete(httpHeaders: inout HTTPHeaders, status: HTTPResponseStatus,
                                             body: (contentType: String, data: Data)?, logger: Logger, internalRequestId: String) {
        // pass the internalRequestId back to the upstream caller
        httpHeaders.add(name: requestIdHeader, value: internalRequestId)
        
        // pass the trace id back to the upstream caller if present
        if let traceId = traceId {
            httpHeaders.add(name: traceIdHeader, value: traceId)
        }
        
        var logMetadata: Logger.Metadata = ["status": "\(status.reasonPhrase)",
                                            "statusCode": "\(status.code)"]
        
        let bodyData: String?
        if let body = body {
            let theBodyData = body.data.debugString
            logMetadata["contentType"] = "\(body.contentType)"
            logMetadata["bodyBytesCount"] = "\(body.data.count)"
            logMetadata["bodyData"] = "\(theBodyData)"
            
            bodyData = theBodyData
        } else {
            bodyData = nil
        }
        
        let level: Logger.Level
        // log at error if this is a server error
        if status.code >= 500 && status.code < 600 {
            level = .error
        } else {
            level = .info
        }
        
        if let span = self.span {
            span.attributes["http.status_code"] = Int(status.code)
            
            if status.code >= 500 && status.code < 600 {
                if let bodyData = bodyData {
                    span.recordError(OperationFailure.withResponseBody(bodyData))
                } else {
                    span.recordError(OperationFailure.withNoResponseBody)
                }
            }
            
            span.end()
        }
        
        if let parentSpan = self.parentSpan {
            parentSpan.end()
        }
        
        logger.log(level: level, "Response to incoming request sent.", metadata: logMetadata)
    }
}
    
extension SmokeInvocationTraceContext: InvocationTraceContext {
    public typealias OutwardsRequestContext = String
    
    public func handleOutwardsRequestStart(method: HTTPMethod, uri: String, logger: Logger, internalRequestId: String,
                                           headers: inout HTTPHeaders, bodyData: Data) -> String {
        var logMetadata: Logger.Metadata = ["method": "\(method)",
                                            "uri": "\(uri)",
                                            "bodyBytesCount": "\(bodyData.count)"]
        
        if logger.logLevel == .trace {
            logMetadata["bodyData"] = "\(bodyData.debugString)"
        }
            
        // log details about the outgoing request
        logger.debug("Starting outgoing request.",
                    metadata: logMetadata)
        
        // pass the internal request id to the downstream caller
        headers.add(name: requestIdHeader, value: internalRequestId)
        
        // pass the trace id to the downstream caller if present
        if let traceId = traceId {
            headers.add(name: traceIdHeader, value: traceId)
        }
        
        return ""
    }
    
     public func handleOutwardsRequestSuccess(outwardsRequestContext: String?, logger: Logger, internalRequestId: String,
                                              response: HTTPClient.Response, bodyData: Data?) {
         logOutwardsRequestCompletion(logger: logger, level: .info, successfullyCompletedRequest: true,
                                      response: response, bodyData: bodyData)
    }
    
    public func handleOutwardsRequestFailure(outwardsRequestContext: String?, logger: Logger, internalRequestId: String,
                                             response: HTTPClient.Response?, bodyData: Data?, error: Error) {
        let level: Logger.Level
        
        // log at error if this is a server error
        if let response = response, response.status.code >= 500 && response.status.code < 600 {
            level = .error
        } else {
            level = .debug
        }
        
        logOutwardsRequestCompletion(logger: logger, level: level, successfullyCompletedRequest: false,
                                     response: response, bodyData: bodyData)
    }
    
    private func logOutwardsRequestCompletion(logger: Logger, level: Logger.Level, successfullyCompletedRequest: Bool,
                                              response: HTTPClient.Response?, bodyData: Data?) {
        var logMetadata: Logger.Metadata = [:]
        
        if successfullyCompletedRequest {
            logMetadata["result"] = "success"
        } else {
            logMetadata["result"] = "failure"
        }
        
        if let status = response?.status {
            logMetadata["statusCode"] = "\(status.code)"
            logMetadata["status"] = "\(status.reasonPhrase)"
        }
        
        if let requestIds = response?.headers[requestIdHeader], !requestIds.isEmpty {
            logMetadata[requestIdHeader] = "\(requestIds.joined(separator: ","))"
        }
        
        if let traceIds = response?.headers[traceIdHeader], !traceIds.isEmpty {
            logMetadata[traceIdHeader] = "\(traceIds.joined(separator: ","))"
        }
        
        if let bodyData = bodyData {
            logMetadata["bodyBytesCount"] = "\(bodyData.count)"
            
            if logger.logLevel == .trace {
                logMetadata["bodyData"] = "\(bodyData.debugString)"
            }
        }
        
        logger.log(level: level, "Outgoing request completed.", metadata: logMetadata)
    }
}

private struct HTTPHeadersExtractor: Extractor {
    func extract(key name: String, from headers: HTTPHeaders) -> String? {
        headers.first(name: name)
    }
}
