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
            
            if logger.logLevel <= .debug {
                logMetadata["bodyData"] = "\(bodyData.debugString)"
            }
        }
        
        // log details about the incoming request
        logger.info("Incoming request received.", metadata: logMetadata)
    }
    
    public func handleInwardsRequestComplete(httpHeaders: inout HTTPHeaders, status: HTTPResponseStatus,
                                             body: (contentType: String, data: Data)?, logger: Logger, internalRequestId: String) {
        // pass the internalRequestId back to the upstream caller
        httpHeaders.add(name: requestIdHeader, value: internalRequestId)
        
        // pass the trace id back to the upstream caller if present
        if let traceId = traceId {
            httpHeaders.add(name: traceIdHeader, value: traceId)
        }
        
        var logMetadata: Logger.Metadata = ["status": "\(status)"]
        
        if let body = body {
            logMetadata["contentType"] = "\(body.contentType)"
            logMetadata["bodyBytesCount"] = "\(body.data.count)"
            
            if logger.logLevel <= .debug {
                logMetadata["bodyData"] = "\(body.data.debugString)"
            }
        }
        
        let level: Logger.Level
        // log at error if this is a server error
        if status.code >= 500 && status.code < 600 {
            level = .error
        } else {
            level = .info
        }
        
        logger.log(level: level, "Incoming response sent.", metadata: logMetadata)
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
        logger.info("Starting outgoing request.",
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
            level = .info
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
        
        if let code = response?.status.code {
            logMetadata["status"] = "\(code)"
        }
        
        if let requestIds = response?.headers[requestIdHeader], !requestIds.isEmpty {
            requestIds.enumerated().forEach { (index, header) in
                logMetadata["\(requestIdHeader)(index)"] = "\(header)"
            }
        }
        
        if let traceIds = response?.headers[traceIdHeader], !traceIds.isEmpty {
            traceIds.enumerated().forEach { (index, header) in
                logMetadata["\(traceIdHeader)(index)"] = "\(header)"
            }
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
