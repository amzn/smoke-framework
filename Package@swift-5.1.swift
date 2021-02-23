// swift-tools-version:5.0
//
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

import PackageDescription

let package = Package(
    name: "SmokeFramework",
    platforms: [
      .macOS(.v10_12), .iOS(.v10)
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
            name: "SmokeInvocation",
            targets: ["SmokeInvocation"]),
        .library(
            name: "SmokeHTTP1",
            targets: ["SmokeHTTP1"]),
        .library(
            name: "SmokeAsync",
            targets: ["SmokeAsync"]),
        .library(
            name: "SmokeAsyncHTTP1",
            targets: ["SmokeAsyncHTTP1"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0"..<"3.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
        .package(url: "https://github.com/amzn/smoke-http.git", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "SmokeInvocation",
            dependencies: ["Logging"]),
        .target(
            name: "SmokeHTTP1",
            dependencies: ["NIO", "NIOHTTP1", "NIOFoundationCompat", "NIOExtras", "Logging",
                           "SmokeHTTPClient", "SmokeInvocation"]),
        .target(
            name: "SmokeOperations",
            dependencies: ["Logging", "Metrics", "SmokeInvocation"]),
        .target(
            name: "SmokeOperationsHTTP1",
            dependencies: ["SmokeOperations", "QueryCoding",
                           "HTTPPathCoding", "HTTPHeadersCoding", "SmokeHTTPClient"]),
        .target(
            name: "SmokeOperationsHTTP1Server",
            dependencies: ["SmokeOperationsHTTP1", "SmokeHTTP1"]),
        .target(
            name: "SmokeAsync",
            dependencies: ["Logging", "NIO", "SmokeOperations"]),
        .target(
            name: "SmokeAsyncHTTP1",
            dependencies: ["NIOHTTP1", "SmokeOperationsHTTP1", "SmokeAsync"]),
        .testTarget(
            name: "SmokeOperationsHTTP1Tests",
            dependencies: ["SmokeOperationsHTTP1"]),
    ],
    swiftLanguageVersions: [.v5]
)
