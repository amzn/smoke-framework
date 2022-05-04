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
//  JSONPayloadLambdaHTTP1ProxyOperationDelegate.swift
//  SmokeOperationsHTTP1LambdaProxy
//

import Foundation
import SmokeOperationsHTTP1
import SmokeOperations
import AWSLambdaRuntime

extension Lambda.Context: InvocationReporting {
    public var internalRequestId: String {
        return self.requestID
    }
}

public typealias JSONPayloadLambdaHTTP1ProxyOperationDelegate =
    GenericJSONPayloadHTTP1OperationDelegate<StandardLambdaHTTP1ProxyResponseHandler, Lambda.Context>
