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
// ServiceContext+invocationContext
// SmokeOperations
//

import ServiceContextModule

public struct InvocationContext {
    var internalRequestId: String
    var incomingOperation: String
    var externalRequestId: String?
    
    public init(internalRequestId: String, incomingOperation: String, externalRequestId: String?) {
        self.internalRequestId = internalRequestId
        self.incomingOperation = incomingOperation
        self.externalRequestId = externalRequestId
    }
}

extension ServiceContext {
    public var invocationContext: InvocationContext? {
        get {
            self[InvocationContextKey.self]
        }
        set {
            self[InvocationContextKey.self] = newValue
        }
    }
}

extension InvocationContext: CustomStringConvertible {
    public var description: String {
        return internalRequestId
    }
}

private enum InvocationContextKey: ServiceContextKey {
    typealias Value = InvocationContext

    static var nameOverride: String? = "smoke-framework-invocation-context"
}
