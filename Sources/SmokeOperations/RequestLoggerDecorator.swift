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
//  RequestLoggerDecorator.swift
//  SmokeOperations
//
import Foundation
import Logging

/**
 Defines that a `SmokeServerInvocationReporting` instance can be retrieved from conforming types.
 */
public protocol RequestLoggerDecorator {

    /// The `Logging.Logger` to use for logging for this invocation.
    func decorate(requestLogger: inout Logger)
}
