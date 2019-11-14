// swift-tools-version:5.0
//
// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
    name: "SmokeFramework",
    products: [
        .library(
            name: "SmokeOperations",
            targets: ["SmokeOperations"]),
        .library(
            name: "SmokeOperationsHTTP1",
            targets: ["SmokeOperationsHTTP1"]),
        .library(
            name: "SmokeHTTP1",
            targets: ["SmokeHTTP1"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        .package(url: "https://github.com/amzn/smoke-http.git", .branch("2.0.0.alpha.1")),
    ],
    targets: [
        .target(
            name: "SmokeHTTP1",
            dependencies: ["NIO", "NIOHTTP1", "NIOFoundationCompat", "NIOExtras", "SmokeOperations", "Logging"]),
        .target(
            name: "SmokeOperations",
            dependencies: ["Logging", "Metrics"]),
        .target(
            name: "SmokeOperationsHTTP1",
            dependencies: ["SmokeOperations", "SmokeHTTP1", "QueryCoding",
                           "HTTPPathCoding", "HTTPHeadersCoding"]),
        .testTarget(
            name: "SmokeOperationsHTTP1Tests",
            dependencies: ["SmokeOperationsHTTP1"]),
    ]
)
