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
//  InvocationStrategy.swift
//  SmokeInvocation
//

import Foundation

/**
 A strategy protocol that manages how to invocate a handler.
 */
public protocol InvocationStrategy {
    
    /**
     Function to handle the invocation of the handler.
 
     - Parameters:
        - handler: The handler to invocate.
     */
    func invoke(handler: @escaping () -> ())
}
