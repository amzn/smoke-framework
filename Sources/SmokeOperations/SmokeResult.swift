// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  SmokeResult.swift
//  SmokeOperations
//

import Foundation

/**
 Result type that is pass to completion handlers by
 async service client methods.
 
 `ResultType` is the type of result produced.
 */
public enum SmokeResult<ResultType> {
    /// The operation was successful and produced the provided result.
    case response(ResultType)
    /// The operation wasn't succesful due to the provided error.
    case error(Error)
}
