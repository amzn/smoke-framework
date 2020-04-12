---
date: 2020-04-11 14:00
description: A step-by-step migration guide from converting a SmokeFramework-based application from version 1.x to 2.x.
tags: SmokeFramework, migration guide
---
# SmokeFramework 1.x to 2.x

The [SmokeFramework](https://github.com/amzn/smoke-framework) is a server-side service framework written in the Swift programming language.

The SmokeFramework has been written and is maintained by a team within PrimeVideo at Amazon. This framework allows us to run a number of micro services written in Swift on ECS/Fargate. 

In addition to the framework package, there is also-

1. A code generator - [Smoke Framework Application Generate](https://github.com/amzn/smoke-framework-application-generate] which is used to generate the boiler-plate code for a service from a Swagger spec file 
2. A number of clients for AWS services - [Smoke AWS](https://github.com/amzn/smoke-aws) - which can be used to connect from the Swift application to AWS services. Credential management is also provided in [Smoke AWS Credentials](https://github.com/amzn/smoke-aws-credentials).

This article will look at how to migrate a SmokeFramework application - specifically one that has used Smoke Framework Application Generate for code generation - from using SmokeFramework 1 to SmokeFramework 2.

## What is SmokeFramework 2

SmokeFramework 2 is the second major version of the framework, taking advantage of developments within the server-side Swift eco-system and also making some improvements in key areas. Due to some of these changes, SmokeFramework 2 is a **breaking** change.

The primary reason for the breaking changes in SmokeFramework 2 is the adoption of [Swift Log](https://github.com/apple/swift-log).

Taking advantage of the standardisation work within the Swift community, this change allows a common logging API to be used across the SmokeFramework and other libraries. 

To take advantage of the features of Swift Log, this required changing SmokeFramework to use a per-invocation logger that is explicitly passed to operation handlers rather than relying on the presence of a global logger.

The benefit of making this change is that log messages can now be tagged with invocation or operation metadata so related log messages - such as from the same invocation - can be easily identified.

Like SmokeFramework 1.x, version 2.x is designed to be run on Linux-based cloud instances but for development can be run locally on macOS. The macOS version requirements for version 2.x have been changed. 

If just the SmokeFramework is used, ***macOS High Sierra (10.13)*** or higher is required.

If SmokeAWS is also used-
* when compiling under Swift 5.2, ***macOS Catalina (10.15)*** or higher is required
* when compiling under Swift 5.1 or Swift 5.0, ***macOS High Sierra (10.13)*** or higher is required

SmokeFramework 2.x drops support for Swift versions prior to 5.0.

## Migration process

### Step 1: Use Smoke Framework Application Generate to regenerate the service


The Smoke Framework Application Generate code generator takes care of a lot of the changes required to migrate to SmokeFramework 2. Use this code generator on our application, making sure to use **serverUpdate** as the generationType.

The instructions for regenerating the application are in the [README](https://github.com/amzn/smoke-framework-application-generate/blob/master/README.md] of the generator's Github repository.

### Step 2: Update the Package Manifest file

#### Step 2a: Update the dependencies

After updating the generated code, the application will no longer compile. The application dependencies will need to be updated to the 2.0 versions. In the application's Package.swift file, the application dependencies should look something like this-

```swift
.package(url: "https://github.com/amzn/smoke-framework.git", .upToNextMajor(from: "1.1.0")),
.package(url: "https://github.com/amzn/smoke-aws-credentials.git", .upToNextMajor(from: "1.0.0")),
.package(url: "https://github.com/amzn/smoke-aws.git", .upToNextMajor(from: "1.0.0")),
.package(url: "https://github.com/amzn/smoke-dynamodb.git", .upToNextMajor(from: "1.0.0")),
```

Update these dependencies to the new versions-

```swift
.package(url: "https://github.com/amzn/smoke-framework.git", .branch("5_2_manifest")),
.package(url: "https://github.com/amzn/smoke-aws-credentials.git", .branch("use_swift_crypto_under_5_2")),
.package(url: "https://github.com/amzn/smoke-aws.git", from: "2.0.0-alpha.6"),
.package(url: "https://github.com/amzn/smoke-dynamodb.git", .branch("use_swift_crypto_under_5_2")),
```

#### Step 2b: Update the target dependencies

Add a dependency on the `SmokeOperationsHTTP1Server` package from `SmokeFramework` to the `\(baseName)Server` target.

#### Step 2c: Verify changes

Following this change, make sure the dependency closure is validation for your application by running-

```
swift package update
```


### Step 3: Update the runtime dependency requirements of the application

If you attempt to compile the application, one of the errors you will get is

```
the product 'XXX' requires minimum platform version 10.12 for macos platform
```

This is because the SmokeFramework projects now have a minimum MacOS version dependency. To correct this there needs to be a couple of additions to to the Package.swift file.

#### Step 3a: Update the Tools version

Make sure the Swift Tools version is 5.0 or higher-

```
Swift-tools-version:5.0
```

#### Step 3b: Update the language version

Specify the language versions supported by the application-

```swift
targets: [
    ...
    ],
swiftLanguageVersions: [.v5]
```

#### Step 3c: Update the supported platforms

Specify the platforms supported by the application-

##### For Swift 5.2

```swift
name: "XXX",
platforms: [
  .macOS(.v10_15), .iOS(.v10)
],
products: [
```

##### For Swift 5.1 or Swift 5.0

```swift
name: "XXX",
platforms: [
  .macOS(.v10_12), .iOS(.v10)
],
products: [
```

### Step 4: Pass the per-invocation logger as part of the operation context

A significant change with SmokeFramework 2 is that logger instances need to be passed into operation handlers for each invocation.

The easiest way to do this to to use the operation context and place the logger in the context. SmokeFramework 2 provides a mechanism to create a per-invocation context with the logger appropriate for that invocation.

#### Step 4a: Add the logger as a context property

To do this, go to the application's operation context and add a logger instance as a property of the type.

```swift
import Logging

...

/**
 The context to be passed to each of the XXX operations.
 */
public struct XXXOperationsContext {
    public let logger: Logger
    ...

    public init(logger: Logger,
                ...) {
        self.logger = logger
        ...
    }
}
```

#### Step 4b: Update any testing instances to take a dummy logger instance.

Modify any test cases that are instantiating a context to take a dummy logger instance.

### Step 5: Modify usages of the logger

Any usages of the previously available global logger will need to be modified to use the per-invocation logger.

Modify any imports of the previously used `LoggerAPI` package to use the `Logging` package-

```swift
import LoggerAPI
```

Should become -

```swift
import Logging
```

And for example

```swift
Log.info("Hello")
```

Should become-

```swift
context.logger.info("Hello")
```

You may need to explicitly pass the context instance to functions that previously didn't need it.

***Note:*** Swift Log doesn't provide a **verbose** log level. You will need to determine what Swift Log level previously verbose level logs will be emitted at.

You may get an error message similar to-

```
Cannot convert value of type 'String' to expected argument type 'Logger.Message'
```

Here you will have to modify the logging statement to not directly pass a string (or a concatenation of strings)-

```swift
context.logger.debug("Some long "
        + "log message")
```

Should become-

```swift
let logMessage = "Some long "
    + "log message"
context.logger.debug("\(logMessage)")
```

### Step 6: Setup the application initializer

Version 2.x of the code generator provides a new mechanism to initialize the application, the `\(baseName)PerInvocationContextInitializer` type. This can be found in the `\(baseName)Service` package.

Copy any application initialization logic into the initalizer of this type. Initialization errors can be thrown out of this constructor and the framework will log the failure.

#### Step 6a: Update EventLoopProvider creation

Use the provided event loop for any clients.

```swift
let clientEventLoopGroup = ...
let clientEventLoopProvider = HTTPClient.EventLoopProvider.use(clientEventLoopGroup)
```

becomes-

```swift
import AsyncHTTPClient

let clientEventLoopProvider = HTTPClient.EventLoopGroupProvider.shared(eventLoop)

```

#### Step 6b: Update client creation to generator creation

Rather than creating clients themselves on application startup, create the generator instances.

```swift
return AWSDynamoDBCompositePrimaryKeyTable(
    credentialsProvider: credentialsProvider,
    region: region, endpointHostName: dynamoEndpointHostName,
    tableName: dynamoTableName,
    eventLoopProvider: clientEventLoopProvider)
```

becomes-

```swift
return AWSDynamoDBCompositePrimaryKeyTableGenerator(
    credentialsProvider: credentialsProvider,
    region: region, endpointHostName: dynamoEndpointHostName,
    tableName: dynamoTableName,
    eventLoopProvider: clientEventLoopProvider)
```

### Step 7: Create a per-invocation context

Add instance variables to this type if required to enable the constructions of an operations context in the `getInvocationContext()` function.

```swift
import Foundation
import XXXOperations
import SmokeOperations
import SmokeOperationsHTTP1
import SmokeDynamoDB
import XXXModel
import SmokeAWSHttp
import Logging

struct XXXPerInvocationContextInitializer: SmokeServerPerInvocationContextInitializer {
    let dynamodbTableGenerator: AWSDynamoDBCompositePrimaryKeyTableGenerator
    let credentialsProvider: StoppableCredentialsProvider
    let awsClientInvocationTraceContext = AWSClientInvocationTraceContext()
    
    init(eventLoop) throws {
    ...
    }
    
    let idGenerator = {
        UUID().uuidString
    }

    public func getInvocationContext(invocationReporting: SmokeServerInvocationReporting<SmokeInvocationTraceContext>) -> XXXOperationsContext {
        let awsClientInvocationReporting = invocationReporting.withInvocationTraceContext(traceContext: awsClientInvocationTraceContext)
        let dynamodbTable = self.dynamodbTableGenerator.with(reporting: awsClientInvocationReporting)
        
        return XXXOperationsContext(
            dynamodbTable: dynamodbTable,
            logger: invocationReporting.logger,
            idGenerator: self.idGenerator)
    }
}
```

### Step 8: Move any shutdown logic

Move any shutdown logic to the `onShutdown()` function. Any any errors can be thrown out of this function and will be logged.

The `wait()` function has been removed from these clients-

```swift
dynamodbTable.close()
dynamodbTable.wait()

credentialsProvider.close()
credentialsProvider.wait()
```

becomes-

```swift
try self.dynamodbTableGenerator.close()

try self.credentialsProvider.close()
```

### Step 8: Delete the \(baseName)Server.swift

Delete the `\(baseName)Server.swift` and update the contents of `main.swift` to use the initializer type.

```swift
import SmokeHTTP1
import SmokeOperationsHTTP1Server

SmokeHTTP1Server.runAsOperationServer(EmptyExamplePerInvocationContextInitializer.init)
```
