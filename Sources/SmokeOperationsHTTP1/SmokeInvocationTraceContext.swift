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
    
    public init(externalRequestId: String? = nil,
                traceId: String? = nil) {
        self.externalRequestId = externalRequestId
        self.traceId = traceId
    }
}

extension SmokeInvocationTraceContext: OperationTraceContext {
    
    public init(requestHead: HTTPRequestHead, bodyData: Data?) {
        let requestIds = requestHead.headers[requestIdHeader]
        let traceIds = requestHead.headers[traceIdHeader]
        
        // get the request id if present
        if !requestIds.isEmpty {
            self.externalRequestId = requestIds.joined(separator: ",")
        } else {
            self.externalRequestId = nil
        }
        
        // get the trace id if present
        if !traceIds.isEmpty {
            self.traceId = traceIds.joined(separator: ",")
        } else {
            self.traceId = nil
        }
    }
    
    public func handleInwardsRequestStart(requestHead: HTTPRequestHead, bodyData: Data?, logger: inout Logger, internalRequestId: String) {
        var logElements: [String] = []
        logElements.append("Incoming \(requestHead.method) request received for uri \(requestHead.uri).")
        
        if let externalRequestId = self.externalRequestId {
            logElements.append("Received \(requestIdHeader) header '\(externalRequestId)'")
            
            logger[metadataKey: requestIdHeader] = "\(externalRequestId)"
        }
        
        if let traceId = self.traceId {
            logElements.append("Received \(traceIdHeader) header '\(traceId)'")
            
            logger[metadataKey: traceIdHeader] = "\(traceId)"
        }
        
        if let bodyData = bodyData {
            logElements.append("Received body with size \(bodyData.count): \(bodyData.debugString)")
        }
        
        // log details about the incoming request
        logger.info("\(logElements.joined(separator: " "))")
    }
    
    public func handleInwardsRequestComplete(httpHeaders: inout HTTPHeaders, status: HTTPResponseStatus,
                                             body: (contentType: String, data: Data)?, logger: Logger, internalRequestId: String) {
        // pass the internalRequestId back to the upstream caller
        httpHeaders.add(name: requestIdHeader, value: internalRequestId)
        
        // pass the trace id back to the upstream caller if present
        if let traceId = traceId {
            httpHeaders.add(name: traceIdHeader, value: traceId)
        }
        
        var logElements: [String] = []
        logElements.append("Incoming request responded with status \(status).")
        
        if let body = body {
            logElements.append("Sent body with content type '\(body.contentType)', size \(body.data.count): \(body.data.debugString)")
        }
        
        // log details about the response to the incoming request
        let logLine = logElements.joined(separator: " ")
        // log at error if this is a server error
        if status.code >= 500 && status.code < 600 {
            logger.error("\(logLine)")
        } else {
            logger.info("\(logLine)")
        }
    }
}
    
extension SmokeInvocationTraceContext: InvocationTraceContext {
    public typealias OutwardsRequestContext = String
    
        public func handleOutwardsRequestStart(method: HTTPMethod, uri: String, logger: Logger, internalRequestId: String,
                                               headers: inout HTTPHeaders, bodyData: Data) -> String {
        // log details about the outgoing request
        logger.info("Starting outgoing \(method) request to endpoint '\(uri)'.")
        logger.debug("Outgoing request body with size \(bodyData.count): \(bodyData.debugString)")
        
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
        let logLine = getLogLine(successfullyCompletedRequest: true, response: response, bodyData: bodyData)
        
        logger.info("\(logLine)")
        
        if let bodyData = bodyData {
            logger.debug("Outgoing response body: \(bodyData.debugString)")
        }
    }
    
    public func handleOutwardsRequestFailure(outwardsRequestContext: String?, logger: Logger, internalRequestId: String,
                                             response: HTTPClient.Response?, bodyData: Data?, error: Error) {
        let logLine = getLogLine(successfullyCompletedRequest: false, response: response, bodyData: bodyData)
        
        // log at error if this is a server error
        if let response = response, response.status.code >= 500 && response.status.code < 600 {
            logger.error("\(logLine)")
        } else {
            logger.info("\(logLine)")
        }
        
        if let bodyData = bodyData {
            logger.debug("Outgoing response body: \(bodyData.debugString)")
        }
    }
    
    private func getLogLine(successfullyCompletedRequest: Bool, response: HTTPClient.Response?, bodyData: Data?) -> String {
        var logElements: [String] = []
        let completionString = successfullyCompletedRequest ? "Successfully" : "Unsuccessfully"
        logElements.append("\(completionString) completed outgoing request.")
        
        if let code = response?.status.code {
            logElements.append("Returned status code: \(code)")
        }
        
        if let requestIds = response?.headers[requestIdHeader], !requestIds.isEmpty {
            logElements.append("Returned \(requestIdHeader) header '\(requestIds.joined(separator: ","))'")
        }
        
        if let traceIds = response?.headers[traceIdHeader], !traceIds.isEmpty {
            logElements.append("Returned \(traceIdHeader) header '\(traceIds.joined(separator: ","))'")
        }
        
        if let bodyData = bodyData {
            logElements.append("Returned body with size \(bodyData.count)")
        }
        
        // log details about the response to the outgoing request
        return logElements.joined(separator: " ")
    }
}
