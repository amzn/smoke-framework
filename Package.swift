// swift-tools-version:5.8
//
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

import PackageDescription

let package = Package(
    name: "smoke-framework",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
        ],
    products: [
        .library(
            name: "SmokeOperations",
            targets: ["SmokeOperations"]),
        .library(
            name: "SmokeOperationsHTTP1",
            targets: ["SmokeOperationsHTTP1"]),
        .library(
            name: "SmokeOperationsHTTP1Server",
            targets: ["SmokeOperationsHTTP1Server"]),
        .library(
            name: "SmokeAsyncHTTP1Server",
            targets: ["SmokeAsyncHTTP1Server"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0"..<"3.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.52.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        .package(url: "https://github.com/amzn/smoke-http.git", from: "2.7.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle", from: "2.0.0-alpha.1"),
        .package(url: "https://github.com/tachyonics/swift-middleware", branch: "poc_3"),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.0-beta"),
    ],
    targets: [
        .target(
            name: "SmokeAsyncHTTP1Server", dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
            ]),
        .target(
            name: "SmokeOperations", dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
            ]),
        .target(
            name: "SmokeOperationsHTTP1", dependencies: [
                .target(name: "SmokeOperations"),
                .product(name: "QueryCoding", package: "smoke-http"),
                .product(name: "HTTPPathCoding", package: "smoke-http"),
                .product(name: "HTTPHeadersCoding", package: "smoke-http"),
                .product(name: "SwiftMiddleware", package: "swift-middleware"),
                .product(name: "Metrics", package: "swift-metrics"),
                .target(name: "SmokeAsyncHTTP1Server"),
            ]),
        .target(
            name: "SmokeOperationsHTTP1Server", dependencies: [
                .target(name: "SmokeOperationsHTTP1"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ]),
        .testTarget(
            name: "SmokeOperationsHTTP1Tests", dependencies: [
                .target(name: "SmokeOperationsHTTP1"),
            ]),
    ],
    swiftLanguageVersions: [.v5]
)
