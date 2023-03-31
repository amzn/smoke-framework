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
// HTTPServerRequestContext.swift
// SmokeOperationsHTTP1
//

import Logging
import SmokeOperations

public struct HTTPServerRequestContext<OperationIdentifer: OperationIdentity> {
    public let logger: Logger?
    public let requestId: String?
    public let requestHead: HTTPServerRequestHead
    public let operationIdentifer: OperationIdentifer
    // This is the raw middleware context from the end of the middleware chain.
    // The exact type is determined by the middleware chain used. An application can
    // check conformance of this type to extract information from the context.
    public let middlewareContext: Any
    
    public init(logger: Logger?, requestId: String?, requestHead: HTTPServerRequestHead,
                operationIdentifer: OperationIdentifer,
                middlewareContext: Any) {
        self.logger = logger
        self.requestId = requestId
        self.requestHead = requestHead
        self.operationIdentifer = operationIdentifer
        self.middlewareContext = middlewareContext
    }
}
