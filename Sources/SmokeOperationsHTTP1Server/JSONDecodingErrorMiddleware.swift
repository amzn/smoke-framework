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
// JSONDecodingErrorMiddleware.swift
// SmokeOperationsHTTP1Server
//

import Foundation
import SmokeAsyncHTTP1Server
import SwiftMiddleware
import Logging
import NIOHTTP1
import SmokeOperations
import SmokeHTTP1ServerMiddleware

public struct JSONDecodingErrorMiddleware<Context: ContextWithMutableLogger,
                                            OutputWriter: HTTPServerResponseWriterProtocol>: MiddlewareProtocol {
    public typealias Input = HTTPServerRequest
    public typealias Output = Void
    
    public func handle(_ input: Input,
                       outputWriter: OutputWriter,
                       context middlewareContext: Context,
                       next: (Input, OutputWriter, Context) async throws -> Void) async throws {
        do {
            return try await next(input, outputWriter, middlewareContext)
        } catch DecodingError.keyNotFound(let codingKey, let context) {
            let codingPath = context.codingPath + [codingKey]
            let description = "Key not found \(codingPath.pathDescription)."
            try await JSONFormat.writeErrorResponse(reason: "DecodingError", errorMessage: description,
                                                    status: .badRequest, logger: middlewareContext.logger,
                                                    outputWriter: outputWriter)
        } catch DecodingError.valueNotFound(_, let context) {
            let description = "Required value not found \(context.codingPath.pathDescription)."
            try await JSONFormat.writeErrorResponse(reason: "DecodingError", errorMessage: description,
                                                    status: .badRequest, logger: middlewareContext.logger,
                                                    outputWriter: outputWriter)
        } catch DecodingError.typeMismatch(let expectedType, let context) {
            // Special case for a dictionary, return as "Structure"
            let expectedTypeString = (expectedType == [String: Any].self) ? "Structure" : String(describing: expectedType)
            let description = "Incorrect type \(context.codingPath.pathDescription). Expected \(expectedTypeString)."
            try await JSONFormat.writeErrorResponse(reason: "DecodingError", errorMessage: description,
                                                    status: .badRequest, logger: middlewareContext.logger,
                                                    outputWriter: outputWriter)
        } catch DecodingError.dataCorrupted(let context) {
            try await JSONFormat.writeErrorResponse(reason: "DecodingError", errorMessage: context.dataCorruptionPathDescription,
                                                    status: .badRequest, logger: middlewareContext.logger,
                                                    outputWriter: outputWriter)
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

private enum CodingKeyType {
    case attribute(String)
    case index(Int)
}

private extension CodingKey {
    var type: CodingKeyType {
        if let intValue = self.intValue {
            return .index(intValue)
        }
        
        return .attribute(self.stringValue)
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
