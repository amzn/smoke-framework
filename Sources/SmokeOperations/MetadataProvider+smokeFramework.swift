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
// MetadataProvider+smokeFramework
// SmokeOperations
//

import Logging
import ServiceContextModule

extension Logger.MetadataProvider {
    /// A metadata provider exposing the attributes of the current invocation.
    ///
    /// - Parameters:
    ///   - internalRequestIdKey: The metadata key of the internalRequestId. Defaults to "internalRequestId".
    ///   - incomingOperationKey: The metadata key of the incomingOperation. Defaults to "incomingOperation".
    ///   - externalRequestIdKey: The metadata key of the externalRequestId. Defaults to "externalRequestId".
    /// - Returns: A metadata provider ready to use with Logging.
    public static func smokeFramework(internalRequestIdKey: String = "internalRequestId",
                                      incomingOperationKey: String = "incomingOperation",
                                      externalRequestIdKey: String = "externalRequestId") -> Logger.MetadataProvider {
        .init {
            guard let invocationContext = ServiceContext.current?.invocationContext else { return [:] }
            
            var metadataProvider: Logger.Metadata = [
                internalRequestIdKey: "\(invocationContext.internalRequestId)",
                incomingOperationKey: "\(invocationContext.incomingOperation)",
            ]
            
            if let externalRequestId = invocationContext.externalRequestId {
                metadataProvider[externalRequestIdKey] = "\(externalRequestId)"
            }
            
            return metadataProvider
        }
    }

    /// A metadata provider exposing the attributes of the current invocation with the default key names.
    public static let smokeFramework = Logger.MetadataProvider.smokeFramework()
}
