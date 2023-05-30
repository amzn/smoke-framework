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
//  BasicServerRouter.swift
//  SmokeOperationsHTTP1
//

import SmokeOperations
import NIOHTTP1
import HTTPPathCoding
import SmokeAsyncHTTP1Server
import ShapeCoding
import Logging

public typealias NonTransformingBasicServerRouter<OperationIdentifer: OperationIdentity> =
    BasicServerRouter<SmokeMiddlewareContext, BasicServerRouterMiddlewareContext<OperationIdentifer>,
                      OperationIdentifer, HTTPServerResponseWriter>

private let incomingOperationKey = "incomingOperation"

public struct BasicServerRouterMiddlewareContext<OperationIdentifer: OperationIdentity>: ContextWithPathShape &
                                                                                         ContextWithMutableLogger &
                                                                                         ContextWithHTTPServerRequestHead &
                                                                                         ContextWithMutableRequestId &
                                                                                         ContextWithOperationIdentifer {
    public let operationIdentifer: OperationIdentifer
    public let pathShape: ShapeCoding.Shape
    public var logger: Logging.Logger?
    public let httpServerRequestHead: SmokeOperationsHTTP1.HTTPServerRequestHead
    public var internalRequestId: String?
}

public struct BasicServerRouter<IncomingMiddlewareContext, OutgoingMiddlewareContext,
                                OperationIdentifer, IncomingOutputWriter>: ServerRouterProtocol
where IncomingMiddlewareContext: ContextWithMutableLogger & ContextWithMutableRequestId,
OperationIdentifer: OperationIdentity, IncomingOutputWriter: HTTPServerResponseWriterProtocol,
IncomingMiddlewareContext: ContextWithMutableLogger & ContextWithMutableRequestId,
OutgoingMiddlewareContext: ContextWithPathShape & ContextWithMutableLogger & ContextWithOperationIdentifer
    & ContextWithHTTPServerRequestHead & ContextWithMutableRequestId{

    private typealias OperationHandlerType =
        @Sendable (HTTPServerRequest, IncomingOutputWriter, BasicServerRouterMiddlewareContext<OperationIdentifer>) async throws -> ()
    
    private struct BasicEntry {
        let handler: OperationHandlerType
        let operationIdentifer: OperationIdentifer
    }
    
    private struct TokenizedEntry {
        let template: String
        let templateSegments: [HTTPPathSegment]
        let httpMethod: HTTPMethod
        let handler: OperationHandlerType
        let operationIdentifer: OperationIdentifer
    }
    
    private var basicEntryMapping: [String: [HTTPMethod: BasicEntry]] = [:]
    private var tokenizedEntryMapping: [TokenizedEntry] = []
    
    public init() {
        
    }

    public func handle(_ input: HTTPServerRequest, outputWriter: IncomingOutputWriter, context: IncomingMiddlewareContext) async throws {
        let lowerCasedUri = input.uri.lowercased()
        
        guard let entry = self.basicEntryMapping[lowerCasedUri]?[input.method] else {
            guard let (tokenizedEntry, shape) = getTokenizedEntry(uri: input.uri,
                                                                  httpMethod: input.method, requestLogger: context.logger) else {
                throw SmokeOperationsError.invalidOperation(
                    reason: "Invalid operation with uri '\(lowerCasedUri)', method '\(input.method)'")
            }
            
            let decoratedLogger = context.logger?.decorateWithOperationIdentifer(operationIdentifer: tokenizedEntry.operationIdentifer)
            let middlewareContext = BasicServerRouterMiddlewareContext(operationIdentifer: tokenizedEntry.operationIdentifer,
                                                                       pathShape: shape,
                                                                       logger: decoratedLogger,
                                                                       httpServerRequestHead: input.asHead(),
                                                                       internalRequestId: context.internalRequestId)
            
            return try await tokenizedEntry.handler(input, outputWriter, middlewareContext)
        }
        
        context.logger?.trace("Operation handler selected.",
                              metadata: ["operationIdentifer": "\(entry.operationIdentifer)",
                                         "uri": "\(input.uri)",
                                         "method": "\(input.method)"])
        
        let decoratedLogger = context.logger?.decorateWithOperationIdentifer(operationIdentifer: entry.operationIdentifer)
        let middlewareContext = BasicServerRouterMiddlewareContext(operationIdentifer: entry.operationIdentifer,
                                                                   pathShape: .null,
                                                                   logger: decoratedLogger,
                                                                   httpServerRequestHead: input.asHead(),
                                                                   internalRequestId: context.internalRequestId)
        
        return try await entry.handler(input, outputWriter, middlewareContext)
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - operationIdentifer: The identifer for the handler being added.
        - httpMethod: The HTTP method this handler will respond to.
        - handler: the handler to add.
     */
    public mutating func addHandlerForOperation(
        _ operationIdentifer: OperationIdentifer,
        httpMethod: HTTPMethod,
        handler: @escaping @Sendable (HTTPServerRequest, IncomingOutputWriter, BasicServerRouterMiddlewareContext<OperationIdentifer>) async throws -> ())
    {
        let uri = operationIdentifer.operationPath
        
        if addTokenizedUri(uri, operationIdentifer: operationIdentifer, httpMethod: httpMethod, handler: handler) {
            return
        }
        
        let lowerCasedUri = uri.lowercased()
        
        let entry = BasicEntry(handler: handler, operationIdentifer: operationIdentifer)
        if var methodMapping = basicEntryMapping[lowerCasedUri] {
            methodMapping[httpMethod] = entry
            basicEntryMapping[lowerCasedUri] = methodMapping
        } else {
            basicEntryMapping[lowerCasedUri] = [httpMethod: entry]
        }
    }
    
    private func getTokenizedEntry(uri: String,
                                   httpMethod: HTTPMethod,
                                   requestLogger: Logger?) -> (entry: TokenizedEntry, shape: Shape)? {
        let pathSegments = HTTPPathSegment.getPathSegmentsForPath(uri: uri)
        
        // iterate through each tokenized entry
        for entry in tokenizedEntryMapping {
            // ignore if not the correct method
            guard entry.httpMethod == httpMethod else {
                continue
            }
            
            let shape: Shape
            do {
                shape = try pathSegments.getShapeForTemplate(templateSegments: entry.templateSegments)
            } catch HTTPPathDecoderErrors.pathDoesNotMatchTemplate(let reason) {
                requestLogger?.error("Path did not match template.",
                                     metadata: ["uri": "\(uri)",
                                                "template": "\(entry.template)",
                                                "reason": "\(reason)"])
                continue
            } catch {
                requestLogger?.error("Path did not match template.",
                                     metadata: ["uri": "\(uri)",
                                                "template": "\(entry.template)",
                                                "cause": "\(String(describing: error))"])
                continue
            }
            
            return (entry, shape)
        }
        
        return nil
    }
    
    private mutating func addTokenizedUri(_ uri: String,
                                          operationIdentifer: OperationIdentifer,
                                          httpMethod: HTTPMethod,
                                          handler: @escaping OperationHandlerType) -> Bool {
        let tokenizedPath: [HTTPPathSegment]
        do {
            tokenizedPath = try HTTPPathSegment.tokenize(template: uri)
        } catch {
            return false
        }
        
        // if this uri doesn't have any tokens (is a single string token)
        if tokenizedPath.count == 1 && tokenizedPath[0].tokens.count == 1,
            case .string = tokenizedPath[0].tokens[0] {
                return false
        }
        
        let tokenizedEntry = TokenizedEntry(
            template: uri,
            templateSegments: tokenizedPath,
            httpMethod: httpMethod, handler: handler,
            operationIdentifer: operationIdentifer)
        
        tokenizedEntryMapping.append(tokenizedEntry)
        
        return true
    }
}

extension HTTPMethod: Hashable {

}

extension HTTPServerRequest {
    func asHead() -> HTTPServerRequestHead {
        return .init(method: self.method, version: self.version, uri: self.uri, headers: self.headers)
    }
}

extension Logger {
    func decorateWithOperationIdentifer<OperationIdentifer: OperationIdentity>(operationIdentifer: OperationIdentifer) -> Logger {
        var decoratedLogger = self
        decoratedLogger[metadataKey: incomingOperationKey] = "\(operationIdentifer)"
        
        return decoratedLogger
    }
}
