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
//  OperationTraceContext.swift
//  SmokeOperations
//

import Foundation
import Logging
import Tracing

public struct RequestSpanParameters {
    public let operationName: String
    public let internalRequestId: String

    public init(operationName: String, internalRequestId: String) {
        self.operationName = operationName
        self.internalRequestId = internalRequestId
    }
}

public enum CreateRequestSpan {
    // A `Tracing.Span` should never be created for a request.
    case never
    // A `Tracing.Span` can be created for a request
    // if the `OperationTraceContext` decides to create one.
    // It is the responsibility of the OperationTraceContext
    // to manage the lifecycle of the span if it creates one,
    // most likely closing it in the
    // `handleInwardsRequestComplete` function.
    case ifRequired(RequestSpanParameters)
}

public struct OperationTraceContextOptions {
    public let createRequestSpan: CreateRequestSpan

    public init(createRequestSpan: CreateRequestSpan) {
        self.createRequestSpan = createRequestSpan
    }
}

public protocol OperationTraceContext {
    associatedtype RequestHeadType
    associatedtype ResponseHeadersType
    associatedtype ResponseStatusType

    var span: Span? { get }

    init(requestHead: RequestHeadType, bodyData: Data?)

    init(requestHead: RequestHeadType, bodyData: Data?, options: OperationTraceContextOptions?)

    func handleInwardsRequestStart(requestHead: RequestHeadType, bodyData: Data?, logger: inout Logger, internalRequestId: String)

    func handleInwardsRequestComplete(httpHeaders: inout ResponseHeadersType, status: ResponseStatusType, body: (contentType: String, data: Data)?,
                                      logger: Logger, internalRequestId: String)

    func recordErrorForInvocation(_ error: Swift.Error)
}

public extension OperationTraceContext {
    // Add options accepting initializer while remaining backwards compatible
    init(requestHead: RequestHeadType, bodyData: Data?, options _: OperationTraceContextOptions?) {
        self.init(requestHead: requestHead, bodyData: bodyData)
    }

    // Add span property while remaining backwards compatible
    var span: Span? {
        return nil
    }

    // Retain backwards-compatibility
    func recordErrorForInvocation(_: Swift.Error) {
        // do nothing by default
    }
}
