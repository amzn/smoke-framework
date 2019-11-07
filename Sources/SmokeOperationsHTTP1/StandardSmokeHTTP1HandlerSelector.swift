// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  StandardSmokeHTTP1HandlerSelector.swift
//  SmokeOperationsHTTP1
//
import Foundation
import SmokeOperations
import NIOHTTP1
import LoggerAPI
import SmokeHTTP1
import HTTPPathCoding
import ShapeCoding

/**
 Implementation of the SmokeHTTP1HandlerSelector protocol that selects a handler
 based on the case-insensitive uri and HTTP method of the incoming request.
 */
public struct StandardSmokeHTTP1HandlerSelector<ContextType, DefaultOperationDelegateType: HTTP1OperationDelegate,
        OperationIdentifer: OperationIdentity>: SmokeHTTP1HandlerSelector {
    public let defaultOperationDelegate: DefaultOperationDelegateType
    
    public typealias SelectorOperationHandlerType = OperationHandler<ContextType,
            DefaultOperationDelegateType.RequestHeadType,
            DefaultOperationDelegateType.ResponseHandlerType,
            OperationIdentifer>
    
    private struct TokenizedHandler {
        let template: String
        let templateSegments: [HTTPPathSegment]
        let httpMethod: HTTPMethod
        let operationHandler: SelectorOperationHandlerType
    }
    
    private var handlerMapping: [String: [HTTPMethod: SelectorOperationHandlerType]] = [:]
    private var tokenizedHandlerMapping: [TokenizedHandler] = []
    
    public init(defaultOperationDelegate: DefaultOperationDelegateType) {
        self.defaultOperationDelegate = defaultOperationDelegate
    }
    
    /**
     Gets the handler to use for an operation with the provided http request
     head.
 
     - Parameters
        - requestHead: the request head of an incoming operation.
     */
    public func getHandlerForOperation(_ uri: String, httpMethod: HTTPMethod) throws -> (SelectorOperationHandlerType, Shape) {
        let lowerCasedUri = uri.lowercased()
        
        guard let handler = handlerMapping[lowerCasedUri]?[httpMethod] else {
            guard let tokenizedHandler = getTokenizedHandler(uri: uri,
                                                             httpMethod: httpMethod) else {
                throw SmokeOperationsError.invalidOperation(reason:
                    "Invalid operation with uri '\(lowerCasedUri)', method '\(httpMethod)'")
                }
            
                return tokenizedHandler
        }
        
        Log.info("Operation handler selected with uri '\(lowerCasedUri)', method '\(httpMethod)'")
        
        return (handler, .null)
    }
    
    private func getTokenizedHandler(uri: String,
                                     httpMethod: HTTPMethod) -> (SelectorOperationHandlerType, Shape)? {
        let pathSegments = HTTPPathSegment.getPathSegmentsForPath(uri: uri)
        
        // iterate through each tokenized handler
        for handler in tokenizedHandlerMapping {
            // ignore if not the correct method
            guard handler.httpMethod == httpMethod else {
                continue
            }
            
            let shape: Shape
            do {
                shape = try pathSegments.getShapeForTemplate(templateSegments: handler.templateSegments)
            } catch HTTPPathDecoderErrors.pathDoesNotMatchTemplate(let reason) {
                Log.verbose("Path '\(uri)' did not match template '\(handler.template)': \(reason)")
                continue
            } catch {
                Log.verbose("Path '\(uri)' did not match template '\(handler.template)': \(error)")
                continue
            }
            
            return (handler.operationHandler, shape)
        }
        
        return nil
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - httpMethod: the http method to add the handler for.
        - handler: the handler to add.
     */
    public mutating func addHandlerForOperation(_ operationIdentifer: OperationIdentifer,
                                                httpMethod: HTTPMethod,
                                                handler: SelectorOperationHandlerType) {
        let uri = operationIdentifer.operationPath
        
        if addTokenizedUri(uri, httpMethod: httpMethod, handler: handler) {
            return
        }
        
        let lowerCasedUri = uri.lowercased()
        
        if var methodMapping = handlerMapping[lowerCasedUri] {
            methodMapping[httpMethod] = handler
            handlerMapping[lowerCasedUri] = methodMapping
        } else {
            handlerMapping[lowerCasedUri] = [httpMethod: handler]
        }
    }
    
    private mutating func addTokenizedUri(_ uri: String,
                                          httpMethod: HTTPMethod,
                                          handler: SelectorOperationHandlerType) -> Bool {
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
        
        let tokenizedHandler = TokenizedHandler(
            template: uri,
            templateSegments: tokenizedPath,
            httpMethod: httpMethod, operationHandler: handler)
        
        tokenizedHandlerMapping.append(tokenizedHandler)
        
        return true
    }
}

extension HTTPMethod: Hashable {

}
