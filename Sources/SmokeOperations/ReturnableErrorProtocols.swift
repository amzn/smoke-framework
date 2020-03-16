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
// ReturnableErrorProtocols
// SmokeOperations
//

import Foundation
import Logging

/// Type alias for an error that also can be identified by its description
public typealias ErrorIdentifiableByDescription =
    Swift.Error & CustomStringConvertible

/// Type alias for an error that can be returned by the Smoke Framework
/// Just be identifiable and encodable
public typealias SmokeReturnableError =
    ErrorIdentifiableByDescription & Encodable

/// Helper protocol for encoding errors
public protocol ErrorEncoder {
    func encode<InputType: SmokeReturnableError>(_ input: InputType, logger: Logger) throws -> Data
}

extension Encodable where Self: SmokeReturnableError {
    public func encode(errorEncoder: ErrorEncoder, logger: Logger) throws -> Data {
        return try errorEncoder.encode(self, logger: logger)
    }
}
