<p align="center">
<a href="https://github.com/amzn/smoke-framework/actions">
<img src="https://github.com/amzn/smoke-framework/actions/workflows/swift.yml/badge.svg?branch=main" alt="Build - Main Branch">
</a>
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-5.7|5.8|5.9-orange.svg?style=flat" alt="Swift 5.7, 5.8 and 5.9 Tested">
</a>
<img src="https://img.shields.io/badge/ubuntu-20.04|22.04-yellow.svg?style=flat" alt="Ubuntu 20.04 and 22.04 Tested">
<img src="https://img.shields.io/badge/CentOS-8-yellow.svg?style=flat" alt="CentOS 8 Tested">
<img src="https://img.shields.io/badge/AmazonLinux-2-yellow.svg?style=flat" alt="Amazon Linux 2 Tested">
<a href="https://gitter.im/SmokeServerSide">
<img src="https://img.shields.io/badge/chat-on%20gitter-ee115e.svg?style=flat" alt="Join the Smoke Server Side community on gitter">
</a>
<img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
</p>

# Smoke Framework

The Smoke Framework is a light-weight server-side service framework written in Swift
and using [SwiftNIO](https://github.com/apple/swift-nio) for its networking layer by
default. The framework can be used for REST-like or RPC-like services and in conjunction
with code generators from service models such as [Swagger/OpenAPI](https://www.openapis.org/).

The framework has built in support for JSON-encoded request and response payloads.

## Support Policy

SmokeFramework follows the same support policy as followed by SmokeAWS [here](https://github.com/amzn/smoke-aws/blob/master/docs/Support_Policy.md).

# Conceptual Overview

The Smoke Framework provides the ability to specify handlers for operations your service application
needs to perform. When a request is received, the framework will decode the request into the operation's
input. When the handler returns, its response (if any) will be encoded and sent in the response.

Each invocation of a handler is also passed an application-specific context, allowing application-scope or invocation-scope
entities such as other service clients to be passed to operation handlers. Using the context allows 
operation handlers to remain *pure* functions (where its return value is determined by the function's 
logic and input values) and hence easily testable.

# SmokeFrameworkExamples

See [this repository](https://github.com/amzn/smoke-framework-examples) for examples of the Smoke Framework and
the related Smoke* repositories in action.

# Getting Started using Code Generation

The Smoke Framework provides a [code generator](https://github.com/amzn/smoke-framework-application-generate) that will
generate a complete Swift Package Manager repository for a SmokeFramework-based service from a Swagger 2.0 specification file.

Using this code generator is the simplest way to get started with smoke-framework. The code generator will provide sub-functions for each
operation in the swagger file.

```swift
extension ExampleOperationsContext {
    func handleExampleOperation(input _: ExampleModel.ExampleOperationInput) async throws 
    -> ExampleModel.ExampleOperationOutput {
        ...
    }
}
```

The code generator also provides an initializer type that can be used to easily initialize global instances required by the application.

```swift
@main
struct ExamplePerInvocationContextInitializer: ExamplePerInvocationContextInitializerProtocol {
    // TODO: Add properties to be accessed by the operation handlers

    /**
     On application startup.
     */
    init(configuration: inout SmokeServerConfiguration) async throws {
        CloudwatchStandardErrorLogger.enableLogging()

        // TODO: Add additional application initialization
    }

    /**
     On invocation.
     */
    public func getInvocationContext(invocationReporting: SmokeServerInvocationReporting<SmokeInvocationTraceContext>)
    -> ExampleOperationsContext {
        return ExampleOperationsContext(logger: invocationReporting.logger)
    }

    /**
     Provide an ordered list of any other services to be run along side the main service.
     */
    func getServices(smokeService: any ServiceLifecycle.Service) -> [any ServiceLifecycle.Service] {
        return [...,
                smokeService,
                ...]
    }
}
```

See the instructions in the code generator repository on how to get started.

# Getting Started without Code Generation

These steps assume you have just created a new swift application using `swift package init --type executable`.

## Step 1: Add the Smoke Framework dependency

The Smoke Framework uses the Swift Package Manager. To use the framework, add the following dependency
to your Package.swift-

```swift
dependencies: [
    .package(url: "https://github.com/amzn/smoke-framework.git", from: "2.0.0")
]

.target(name: ..., dependencies: [
    ..., 
    .product(name: "SmokeOperationsHTTP1Server", package: "smoke-framework"),
]),
```


## Step 2: Update the runtime dependency requirements of the application

If you attempt to compile the application, you will get the error

```
the product 'XXX' requires minimum platform version 10.12 for macos platform
```

This is because SmokeFramework projects have a minimum MacOS version dependency. To correct this there needs to be a couple of additions to to the Package.swift file.

### Step 2a: Update the language version

Specify the language versions supported by the application-

```swift
targets: [
    ...
    ],
swiftLanguageVersions: [.v5]
```

### Step 2b: Update the supported platforms

Specify the platforms supported by the application-

```swift
name: "XXX",
platforms: [
  .macOS(.v10_15), .iOS(.v10)
],
products: [
```


## Step 2: Add a Context Type

An instance of the context type will be passed to each invocation of an operation that needs to be handled. This instance can be setup to be initialized per invocation or once for the application.

You will need to create this context type. There are no requirements for a type to be passed as a context. The following code shows an example of creating the context type-

```swift
public struct MyApplicationContext {
    let logger: Logger
    // TODO: Add properties to be accessed by the operation handlers
    
    public init(logger: Logger) {
        self.logger = logger
    }
}
```

## Step 3: Add an Operation Function

The next step to using the Smoke Framework is to define one or more functions that will perform the operations
that your application requires. The following code shows an example of such a function-

```swift
extension MyApplicationContext {
    func handleTheOperation(input: OperationInput) throws -> OperationOutput {
        return OperationOutput()
    }
}
```

This particular operation function accepts the input to the operation and is within an extension of the context (giving it access to any attributes or functions on this type) while
returning the output from the operation.

For HTTP1, the operation input can conform to [OperationHTTP1InputProtocol](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperationsHTTP1/OperationHTTP1InputProtocol.swift), which defines how the input type is constructed from
the HTTP1 request. Similarly, the operation output can conform to [OperationHTTP1OutputProtocol](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperationsHTTP1/OperationHTTP1OutputProtocol.swift), which defines how to construct
the HTTP1 response from the output type. Both must also conform to the [Validatable](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperations/Validatable.swift#L23) protocol, giving the opportunity to validate any field constraints.

As an alternative, both operation input and output can conform to the `Codable` protocol if
they are constructed from only one part of the HTTP1 request and response.

The Smoke Framework also supports additional built-in and custom operation function signatures. See the *The Operation Function*
and *Extension Points* sections for more information.

## Step 4: Add Handler Selection

After defining the required operation handlers, it is time to specify how they are selected for incoming requests.

The Smoke Framework provides the [SmokeHTTP1HandlerSelector](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperationsHTTP1/SmokeHTTP1HandlerSelector.swift) protocol to add handlers to a selector.


```swift
import SmokeOperationsHTTP1

public enum MyOperations: String, Hashable, CustomStringConvertible {
    case theOperation = "TheOperation"

    public var description: String {
        return rawValue
    }

    public var operationPath: String {
        switch self {
        case .theOperation:
            return "/theOperation"
        }
    }
}

public extension MyOperations {
    static func addToSmokeServer<SelectorType: SmokeHTTP1HandlerSelector>(selector: inout SelectorType)
            where SelectorType.ContextType == MyApplicationContext,
                  SelectorType.OperationIdentifer == MyOperations {
        
        let allowedErrorsForTheOperation: [(MyApplicationErrors, Int)] = [(.unknownResource, 404)]
        selector.addHandlerForOperationProvider(.theOperation, httpMethod: .POST,
                                                operationProvider: MyApplicationContext.handleTheOperation,
                                                allowedErrors: allowedErrorsForTheOperation)
    }
}
```

Each handler added requires the following parameters to be specified:
* The operation to be added. This must be of a type conforming to [OperationIdentity](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperations/OperationIdentity.swift) such as an [enum](https://github.com/amzn/smoke-framework-examples/blob/master/PersistenceExampleService/Sources/PersistenceExampleModel/PersistenceExampleModelOperations.swift). 
  * The HTTP method that must be matched by the incoming request to select the handler.
  * The function to be invoked.
  * The errors that can be returned to the caller from this handler. The error type must also conform to `CustomStringConvertible` that returns the identity of the current error.
  * The location in the HTTP1 request to construct the operation input type from (only required if the input type conforms to `Codable`)
  * The location in the HTTP1 response that the output type represents (only required if the output type conforms to `Codable`)

## Step 5: Setting up the Application Server

The final step is to setup an application as an operation server.

```swift
import Foundation
import SmokeOperationsHTTP1Server
import AsyncHTTPClient
import NIO
import SmokeHTTP1

struct MyPerInvocationContextInitializer: StandardJSONSmokeServerPerInvocationContextInitializerV2 {
    typealias ContextType = MyApplicationContext
    typealias OperationIdentifer = MyOperations
    
    let serverName = "MyService"
    // specify the operations initializer
    let operationsInitializer: OperationsInitializerType = MyOperations.addToSmokeServer

    /**
     On application startup.
     */
    init(configuration: inout SmokeServerConfiguration) async throws {
        // set up any of the application-wide context
    }

    /**
     On invocation.
    */
    public func getInvocationContext(
        invocationReporting: SmokeServerInvocationReporting<SmokeInvocationTraceContext>) -> MyApplicationContext {
        // create an invocation-specific context to be passed to an operation handler
        return MyApplicationContext(logger: invocationReporting.logger)
    }

    /**
     On application shutdown.
    */
    func onShutdown() throws {
        // shutdown anything before the application closes
    }
}

SmokeHTTP1Server.runAsOperationServer(MyPerInvocationContextInitializer.init)
```

You can now run the application and the server will start up on port 8080. The application will block in the
`SmokeHTTP1Server.runAsOperationServer` call. When the server has been fully shutdown and has
completed all requests, `onShutdown` will be called. In this function you can close/shutdown
any clients or credentials that were created on application startup.

## Step 6: Add Reporting Configuration (Optional)

An optional configuration step is to setup the reporting configuration for metrics emitted by the Smoke Framework.
This involves overriding the default `reportingConfiguration` attribute on the initializer. For the metrics to be
emitted, a `swift-metrics` backend - such as [CloudWatchMetricsFactory](https://github.com/amzn/smoke-aws/blob/main/Sources/SmokeAWSMetrics/CloudWatchMetricsFactory.swift) - will need to be initialized.

```swift
...

struct MyPerInvocationContextInitializer: StandardJSONSmokeServerPerInvocationContextInitializerV2 {
    typealias ContextType = MyApplicationContext
    typealias OperationIdentifer = MyOperations
    
    let serverName = "MyService"
    // specify the operations initializer
    let operationsInitializer: OperationsInitializerType = MyOperations.addToSmokeServer

    /**
     On application startup.
     */
    init(configuration: inout SmokeServerConfiguration) async throws {
        // set up any of the application-wide context
        
        // for the server, only report the latency metrics
        // only report 5XX error counts for TheOperation (even if additional operations are added in the future)
        // only report 4XX error counts for operations other than TheOperation (as they are added in the future)
        configuration.reportingConfiguration = SmokeReportingConfiguration(
            successCounterMatchingRequests: .none,
            failure5XXCounterMatchingRequests: .onlyForOperations([.theOperation]),
            failure4XXCounterMatchingRequests: .exceptForOperations([.theOperation]),
            requestReadLatencyTimerMatchingRequests: .none,
            latencyTimerMatchingRequests: .all,
            serviceLatencyTimerMatchingRequests: .all,
            outwardServiceCallLatencyTimerMatchingRequests: .all,
            outwardServiceCallRetryWaitTimerMatchingRequests: .all)
    }

    ...
}

SmokeHTTP1Server.runAsOperationServer(MyPerInvocationContextInitializer.init)
```

# Enabling Distributed Tracing

Initializers using `StandardJSONSmokeServerPerInvocationContextInitializer` will participate in distributed traces by default

This will enable tracing for any operation handlers that use Swift Concurrency (async/await). You will also 
need to setup an Instrumentation backend by following the instructions [here](https://swiftpackageindex.com/apple/swift-distributed-tracing/1.0.0/documentation/tracing/traceyourapplication).

# Further Concepts

## The Application Context

An instance of the application context type is created at application start-up and is passed
to each invocation of an operation handler. The framework imposes no restrictions on this 
type and simply passes it through to the operation handlers. It is *recommended* that this
context is immutable as it can potentially be passed to multiple handlers simultaneously. 
Otherwise, the context type is responsible for handling its own thread safety.

It is recommended that applications use a **strongly typed** context rather than a *bag of 
stuff* such as a Dictionary.

## The Operation Delegate

The Operation Delegate handles specifics such as encoding and decoding requests to the handler's 
input and output.

The Smoke Framework provides the [JSONPayloadHTTP1OperationDelegate](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperationsHTTP1Server/JSONPayloadHTTP1OperationDelegate.swift#L21) implementation that expects 
a JSON encoded request body as the handler's input and returns the output as the JSON encoded
response body.

Each `addHandlerForOperation` invocation can optionally accept an operation delegate to use when that
handler is selected. This can be used when operations have specific encoding or decoding requirements.
A default operation delegate is set up at server startup to be used for operations without a specific
handler or when no handler matches a request.

## The Trace Context

The `JSONPayloadHTTP1OperationDelegate` takes a generic parameter conforming to the [HTTP1OperationTraceContext](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperationsHTTP1Server/HTTP1OperationTraceContext.swift) protocol. This protocol can be used to providing request-level tracing. The requirements for this protocol are defined [here](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperations/OperationTraceContext.swift#L21).

A default implementation - [SmokeInvocationTraceContext](https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperationsHTTP1Server/SmokeInvocationTraceContext.swift#L48) - provides some basic tracing using request and response headers.

## The Operation Function

Each handler provides a function to be invoked when the handler is selected. By default, the Smoke
framework provides four function signatures declared on the Context Type that this function can conform to-

* `((InputType) throws -> ())`: Synchronous method with no output.
* `((InputType) throws -> OutputType)`: Synchronous method with output.
* `((InputType, (Swift.Error?) -> ()) throws -> ())`: Asynchronous method with no output.
* `((InputType, (Result<OutputType, Error>) -> ()) throws -> ())`: Asynchronous method with output.

Due to Swift type inference, a handler can switch between these different signatures without changing the
handler selector declaration - simply changing the function signature is sufficient.

The synchronous variants will return a response as soon as the function returns either with an empty body or 
the encoded return value. The asynchronous variants will return a response when the provided result handlers
are called.

```swift
public protocol Validatable {
    func validate() throws
}
```

In all cases, the InputType and OutputType types must conform to the `Validatable` protocol. This
protocol gives a type the opportunity to verify its fields - such as for string length, numeric
range validation. The Smoke Framework will call validate on operation inputs before passing it to the
handler and operation outputs after receiving from the handler-
* If an operation input fails its validation call (by throwing an error), the framework will fail the operation
  with a 400 ValidationError response, indicating an error by the caller (the framework also logs this event 
  at *Info* level).
* If an operation output fails its validation call (by throwing an error), the framework will fail the operation
  with a 500 Internal Server Error, indicating an error by the service logic (the framework also logs this event 
  at *Error* level).
  
  Additionally, the Smoke Framework provides the option to declare operation handlers outside the Context Type as standalone functions.
  The Context Type is passed in directly to these functions.

  ```swift
  func handleTheOperation(input: OperationInput, context: MyApplicationContext) throws -> OperationOutput {
      return OperationOutput()
  }
  ```

  Adding the handler selection is slightly different in this case-

  ```swift
  import SmokeOperationsHTTP1

  public func addOperations<SelectorType: SmokeHTTP1HandlerSelector>(selector: inout SelectorType)
          where SelectorType.ContextType == MyApplicationContext,
                SelectorType.OperationIdentifer == MyOperations {
      
      let allowedErrorsForTheOperation: [(MyApplicationErrors, Int)] = [(.unknownResource, 404)]
      selector.addHandlerForOperation(.theOperation, httpMethod: .POST,
                                      operation: handleTheOperation,
                                      allowedErrors: allowedErrorsForTheOperation)
  }
  ```
  
 The four function signatures are also available when using this style of operation handlers.

  * `((InputType, ContextType) throws -> ())`: Synchronous method with no output.
  * `((InputType, ContextType) throws -> OutputType)`: Synchronous method with output.
  * `((InputType, ContextType, (Swift.Error?) -> ()) throws -> ())`: Asynchronous method with no output.
  * `((InputType, ContextType, (Result<OutputType, Error>) -> ()) throws -> ())`: Asynchronous method with output.

## Error Handling

By default, any errors thrown from an operation handler will fail the operation and the framework will return a
500 Internal Server Error to the caller (the framework also logs this event at *Error* level). This behavior 
prevents any unintentional leakage of internal error information.

```swift
public typealias ErrorIdentifiableByDescription = Swift.Error & CustomStringConvertible
public typealias SmokeReturnableError = ErrorIdentifiableByDescription & Encodable
```  

Errors can be explicitly encoded and returned to the caller by conforming to the `Swift.Error`, `CustomStringConvertible`
and `Encodable` protocols **and** being specified under *allowedErrors* in the `addHandlerForUri` call setting up the
operation handler. For example-

```swift
public enum MyError: Swift.Error {
    case theError(reason: String)
    
    enum CodingKeys: String, CodingKey {
        case reason = "Reason"
    }
}

extension MyError: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .theError(reason: let reason):
            try container.encode(reason, forKey: .reason)
        }
    }
}

extension MyError: CustomStringConvertible {
    public var description: String {
        return "TheError"
    }
}
```

When such an error is returned from an operation handler-
* A response is returned to the caller with the HTTP code specified in the *allowedErrors* entry with a payload 
  of the error encoded according to the *Encodable* protocol. 
* In addition, the provided error identity of the error will be specified in the **__type** field of the 
  returned payload.
* Comparison between the error specified in the *allowedErrors* list and the error thrown from the operation handler
  is a string comparison between the respective error identities. This is to allow equivalent errors of differing type
  (such as code generated errors from different models) to be handled as the same error.
* For the built-in asynchronous operation functions, errors can either be thrown synchronously from the function itself
  or passed asynchronously to the result handler. Either way, the operation will fail according to the type of error thrown
  or passed. This is to avoid functions having to catch synchronous errors (such as in setup) only to pass them to the
  result handler. 

## Testing

The Smoke Framework has been designed to make testing of operation handlers straightforward. It is recommended that operation
handlers are *pure* functions (where its return value is determined by the function's logic and input values). In this case,
the function can be called in unit tests with appropriately constructed input and context instances.

It is recommended that the application-specific context be used to vary behavior between release and testing executions - 
such as mocking service clients, random number generators, etc. In general this will create more maintainable tests by keeping
all the testing logic in the testing function.

If you want to run all test cases in Smoke Framework, please open command line and go to `smoke-framework` (root) directory, run `swift test` and then you should be able to see test cases result. 

# Extension Points

The Smoke Framework is designed to be extensible beyond its current functionality-
* `JSONPayloadHTTP1OperationDelegate` provides basic JSON payload encoding and decoding. Instead, the `HTTP1OperationDelegate` protocol can
  be used to create a delegate that provides alternative payload encoding and decoding. Instances of this protocol are given
  the entire HttpRequestHead and request body when decoding the input and encoding the output for situations when these are required.
* `StandardSmokeHTTP1HandlerSelector` provides a handler selector that compares the HTTP URI and verb to select a
  handler. Instead, the `SmokeHTTP1HandlerSelector` protocol can be used to create a selector that can use any property
  from the HTTPRequestHead (such as headers) to select a handler.
* Even if `StandardSmokeHTTP1HandlerSelector` does fit your requirements, it can be extended to support additional function
  signatures. See the built-in function signatures (one can be found in OperationHandler+nonblockingWithInputWithOutput.swift)
  for examples of this.
* The Smoke Framework currently supports HTTP1 but can be extended to additional protocols while using the same operation handlers
  if needed. The initializers of `OperationHandler` provide a protocol-agnostic layer - as an example [1] - which can be used by a
  protocol-specific layer - such as [2] for HTTP1 - to abstract protocol-specific handling for the different operation types. 


[1] https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperations/OperationHandler%2BblockingWithInputWithOutput.swift

[2] https://github.com/amzn/smoke-framework/blob/master/Sources/SmokeOperationsHTTP1/SmokeHTTP1HandlerSelector%2BblockingWithInputWithOutput.swift

## License

This library is licensed under the Apache 2.0 License.
