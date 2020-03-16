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
//  JSONPayloadHTTP1OperationDelegate.swift
//  SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations
import SmokeHTTP1
import HTTPPathCoding
import HTTPHeadersCoding
import QueryCoding
import Logging

internal struct MimeTypes {
    static let json = "application/json"
}

internal struct JSONErrorEncoder: ErrorEncoder {
    public func encode<InputType>(_ input: InputType, logger: Logger) throws -> Data where InputType: SmokeReturnableError {
        return JSONEncoder.encodePayload(payload: input, logger: logger,
                                         reason: input.description)
    }
}

public typealias JSONPayloadHTTP1OperationDelegate<TraceContextType: HTTP1OperationTraceContext> =
    GenericJSONPayloadHTTP1OperationDelegate<StandardHTTP1ResponseHandler<SmokeServerInvocationContext<TraceContextType>>, TraceContextType>

/**
 Struct conforming to the OperationDelegate protocol that handles operations from HTTP1 requests with JSON encoded
 request and response payloads.
 */
public struct GenericJSONPayloadHTTP1OperationDelegate<ResponseHandlerType: HTTP1ResponseHandler,
                                                       TraceContextType: HTTP1OperationTraceContext>: HTTP1OperationDelegate
        where ResponseHandlerType.InvocationContext == SmokeServerInvocationContext<TraceContextType> {
    public init() {
        
    }
    
    public func decorateLoggerForAnonymousRequest(requestLogger: inout Logger) {
        // nothing to do
    }
    
    public func getInputForOperation<InputType: OperationHTTP1InputProtocol>(requestHead: SmokeHTTP1RequestHead,
                                                                             body: Data?) throws -> InputType {
        
        func queryDecodableProvider() throws -> InputType.QueryType {
            return try QueryDecoder().decode(InputType.QueryType.self,
                                             from: requestHead.query)
        }
        
        func pathDecodableProvider() throws -> InputType.PathType {
            return try HTTPPathDecoder().decode(InputType.PathType.self,
                                                fromShape: requestHead.pathShape)
        }
        
        func bodyDecodableProvider() throws -> InputType.BodyType {
            if let body = body {
                return try JSONDecoder.getFrameworkDecoder().decode(InputType.BodyType.self, from: body)
            } else {
                throw SmokeOperationsError.validationError(reason: "Input body expected; none found.")
            }
        }
        
        func headersDecodableProvider() throws -> InputType.HeadersType {
            let headers: [(String, String?)] =
                requestHead.httpRequestHead.headers.map { header in
                    return (header.name, header.value)
            }
            return try HTTPHeadersDecoder().decode(InputType.HeadersType.self,
                                                   from: headers)
        }
        
        return try InputType.compose(queryDecodableProvider: queryDecodableProvider,
                                     pathDecodableProvider: pathDecodableProvider,
                                     bodyDecodableProvider: bodyDecodableProvider,
                                     headersDecodableProvider: headersDecodableProvider)
    }
    
    public func getInputForOperation<InputType>(requestHead: SmokeHTTP1RequestHead,
                                                body: Data?,
                                                location: OperationInputHTTPLocation) throws
        -> InputType where InputType: Decodable {
        
            switch location {
            case .body:
                let wrappedInput: BodyOperationHTTPInput<InputType> =
                    try getInputForOperation(requestHead: requestHead, body: body)
                
                return wrappedInput.body
            case .query:
                let wrappedInput: QueryOperationHTTPInput<InputType> =
                    try getInputForOperation(requestHead: requestHead, body: body)
                
                return wrappedInput.query
            case .path:
                let wrappedInput: PathOperationHTTPInput<InputType> =
                    try getInputForOperation(requestHead: requestHead, body: body)
                
                return wrappedInput.path
            case .headers:
                let wrappedInput: HeadersOperationHTTPInput<InputType> =
                    try getInputForOperation(requestHead: requestHead, body: body)
                
                return wrappedInput.headers
            }
    }
    
    public func handleResponseForOperation<OutputType>(
            requestHead: SmokeHTTP1RequestHead, output: OutputType,
            responseHandler: ResponseHandlerType,
            invocationContext: SmokeServerInvocationContext<TraceContextType>) where OutputType: OperationHTTP1OutputProtocol {
        // encode the response within the event loop of the server to limit the number of response
        // `Data` objects that exist at single time to the number of threads in the event loop
        responseHandler.executeInEventLoop(invocationContext: invocationContext) {
            self.handleResponseForOperationInEventLoop(requestHead: requestHead, output: output, responseHandler: responseHandler,
                                                       invocationContext: invocationContext)
        }
    }
    
    private func handleResponseForOperationInEventLoop<OutputType>(
            requestHead: SmokeHTTP1RequestHead, output: OutputType,
            responseHandler: ResponseHandlerType,
            invocationContext: SmokeServerInvocationContext<TraceContextType>) where OutputType: OperationHTTP1OutputProtocol {
        let body: (contentType: String, data: Data)?
        
        if let bodyEncodable = output.bodyEncodable {
            let encodedOutput: Data
            do {
                encodedOutput = try JSONEncoder.getFrameworkEncoder().encode(bodyEncodable)
            } catch {
                invocationContext.invocationReporting.logger.error("Serialization error: unable to encode response: \(error)")
                
                handleResponseForInternalServerError(requestHead: requestHead, responseHandler: responseHandler, invocationContext: invocationContext)
                return
            }
            
            body = (contentType: MimeTypes.json, data: encodedOutput)
        } else {
            body = nil
        }
        
        let additionalHeaders: [(String, String)]
        if let additionalHeadersEncodable = output.additionalHeadersEncodable {
            let headers: [(String, String?)]
            do {
                headers = try HTTPHeadersEncoder().encode(additionalHeadersEncodable)
            } catch {
                invocationContext.invocationReporting.logger.error("Serialization error: unable to encode response: \(error)")
                
                handleResponseForInternalServerError(requestHead: requestHead, responseHandler: responseHandler, invocationContext: invocationContext)
                return
            }
            
            additionalHeaders = headers.compactMap { header in
                guard let value = header.1 else {
                    return nil
                }
                
                return (header.0, value)
            }
        } else {
            additionalHeaders = []
        }
        
        let responseComponents = HTTP1ServerResponseComponents(
            additionalHeaders: additionalHeaders,
            body: body)
        
        responseHandler.complete(invocationContext: invocationContext, status: .ok, responseComponents: responseComponents)
    }
    
    public func handleResponseForOperation<OutputType>(
            requestHead: SmokeHTTP1RequestHead,
            location: OperationOutputHTTPLocation,
            output: OutputType,
            responseHandler: ResponseHandlerType,
            invocationContext: SmokeServerInvocationContext<TraceContextType>) where OutputType: Encodable {
        switch location {
        case .body:
            let wrappedOutput = BodyOperationHTTPOutput<OutputType>(
                bodyEncodable: output)
            
            handleResponseForOperation(requestHead: requestHead,
                                       output: wrappedOutput,
                                       responseHandler: responseHandler,
                                       invocationContext: invocationContext)
        case .headers:
            let wrappedOutput = AdditionalHeadersOperationHTTPOutput<OutputType>(
                additionalHeadersEncodable: output)
            
            handleResponseForOperation(requestHead: requestHead,
                                       output: wrappedOutput,
                                       responseHandler: responseHandler,
                                       invocationContext: invocationContext)
        }
    }
    
    public func handleResponseForOperationWithNoOutput(requestHead: SmokeHTTP1RequestHead,
                                                       responseHandler: ResponseHandlerType,
                                                       invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        let responseComponents = HTTP1ServerResponseComponents(additionalHeaders: [], body: nil)
        responseHandler.completeInEventLoop(invocationContext: invocationContext, status: .ok, responseComponents: responseComponents)
    }
    
    public func handleResponseForOperationFailure(
            requestHead: SmokeHTTP1RequestHead,
            operationFailure: OperationFailure,
            responseHandler: ResponseHandlerType,
            invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        // encode the response within the event loop of the server to limit the number of response
        // `Data` objects that exist at single time to the number of threads in the event loop
        responseHandler.executeInEventLoop(invocationContext: invocationContext) {
            self.handleResponseForOperationFailureInEventLoop(requestHead: requestHead,
                                                              operationFailure: operationFailure,
                                                              responseHandler: responseHandler,
                                                              invocationContext: invocationContext)
        }
    }
    
    private func handleResponseForOperationFailureInEventLoop(
            requestHead: SmokeHTTP1RequestHead,
            operationFailure: OperationFailure,
            responseHandler: ResponseHandlerType,
            invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        let encodedOutput: Data
        let logger = invocationContext.invocationReporting.logger
        
        do {
            encodedOutput = try operationFailure.error.encode(errorEncoder: JSONErrorEncoder(), logger: logger)
        } catch {
            logger.error("Serialization error: unable to encode response: \(error)")
            
            handleResponseForInternalServerError(requestHead: requestHead,
                                                 responseHandler: responseHandler, invocationContext: invocationContext)
            return
        }
        
        let body = (contentType: MimeTypes.json, data: encodedOutput)
        let responseComponents = HTTP1ServerResponseComponents(additionalHeaders: [], body: body)

        responseHandler.complete(invocationContext: invocationContext, status: .custom(code: UInt(operationFailure.code),
                                                                                       reasonPhrase: operationFailure.error.description),
                                 responseComponents: responseComponents)
    }
    
    public func handleResponseForInternalServerError(requestHead: SmokeHTTP1RequestHead,
                                                     responseHandler: ResponseHandlerType,
                                                     invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        handleError(code: 500, reason: "InternalError", message: nil,
                    responseHandler: responseHandler, invocationContext: invocationContext)
    }
    
    public func handleResponseForInvalidOperation(requestHead: SmokeHTTP1RequestHead,
                                                  message: String, responseHandler: ResponseHandlerType,
                                                  invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        handleError(code: 400, reason: "InvalidOperation", message: message,
                    responseHandler: responseHandler, invocationContext: invocationContext)
    }
    
    public func handleResponseForDecodingError(requestHead: SmokeHTTP1RequestHead,
                                               message: String, responseHandler: ResponseHandlerType,
                                               invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        handleError(code: 400, reason: "DecodingError", message: message,
                    responseHandler: responseHandler, invocationContext: invocationContext)
    }
    
    public func handleResponseForValidationError(requestHead: SmokeHTTP1RequestHead,
                                                 message: String?, responseHandler: ResponseHandlerType,
                                                 invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        handleError(code: 400, reason: "ValidationError", message: message,
                    responseHandler: responseHandler, invocationContext: invocationContext)
    }
    
    internal func handleError(code: Int,
                              reason: String,
                              message: String?,
                              responseHandler: ResponseHandlerType,
                              invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        // encode the response within the event loop of the server to limit the number of response
        // `Data` objects that exist at single time to the number of threads in the event loop
        responseHandler.executeInEventLoop(invocationContext: invocationContext) {
            self.handleErrorInEventLoop(code: code, reason: reason, message: message,
                                        responseHandler: responseHandler, invocationContext: invocationContext)
        }
    }
    
    internal func handleErrorInEventLoop(code: Int,
                                         reason: String,
                                         message: String?,
                                         responseHandler: ResponseHandlerType,
                                         invocationContext: SmokeServerInvocationContext<TraceContextType>) {
        let errorResult = SmokeOperationsErrorPayload(errorMessage: message)
        let encodedError = JSONEncoder.encodePayload(payload: errorResult, logger: invocationContext.invocationReporting.logger,
                                                     reason: reason)
        
        let body = (contentType: MimeTypes.json, data: encodedError)
        let responseComponents = HTTP1ServerResponseComponents(additionalHeaders: [], body: body)

        responseHandler.complete(invocationContext: invocationContext, status: .custom(code: UInt(code), reasonPhrase: reason),
                                 responseComponents: responseComponents)
    }
}
