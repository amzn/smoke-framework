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
//  JSONPayloadHTTP1OperationDelegate.swift
//  SmokeOperationsHTTP1Server
//

import SmokeOperations
import SmokeOperationsHTTP1

public typealias JSONPayloadHTTP1OperationDelegate<TraceContextType: HTTP1OperationTraceContext> =
    GenericJSONPayloadHTTP1OperationDelegate<
        StandardHTTP1ResponseHandler<SmokeInvocationContext<SmokeServerInvocationReporting<TraceContextType>>>,
        SmokeServerInvocationReporting<TraceContextType>>
