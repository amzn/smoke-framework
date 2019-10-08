<p align="center">
<a href="https://travis-ci.com/amzn/smoke-framework">
<img src="https://travis-ci.com/amzn/smoke-framework.svg?branch=master" alt="Build - Master Branch">
</a>
<img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-5.0-orange.svg?style=flat" alt="Swift 5.0 Compatible">
</a>
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-5.1-orange.svg?style=flat" alt="Swift 5.1 Compatible">
</a>
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

# Conceptual Overview

The Smoke Framework provides the ability to specify handlers for operations your service application
needs to perform. When a request is received, the framework will decode the request into the operation's
input. When the handler returns, its response (if any) will be encoded and sent in the response.

Each invocation of a handler is also passed an application-specific context, allowing application-scope
entities such as other service clients to be passed to operation handlers. Using the context allows 
operation handlers to remain *pure* functions (where its return value is determined by the function's 
logic and input values) and hence easily testable.

# SmokeFrameworkExamples

See [this repository](https://github.com/amzn/smoke-framework-examples) for examples of the Smoke Framework and
the related Smoke* repositories in action.

# Getting Started using Code Generation

The Smoke Framework provides a [code generator](https://github.com/amzn/smoke-framework-application-generate) that will
generate a complete Swift Package Manager repository for a SmokeFrammework-based service from a Swagger 2.0 specification file.

See the instructions in the code generator repository on how to get started.

# Getting Started without Code Generation

## Step 1: Add the Smoke Framework dependency

The Smoke Framework uses the Swift Package Manager. To use the framework, add the following dependency
to your Package.swift-

```swift
dependencies: [
    .package(url: "https://github.com/amzn/smoke-framework.git", .upToNextMajor(from: "1.0.0"))
]

.target(
    name: ...,
    dependencies: [..., "SmokeOperations", "SmokeOperationsHTTP1"]),
```

## Step 2: Add an Operation Function

The next step to using the Smoke Framework is to define one or more functions that will perform the operations
that your application requires. The following code shows an example of such a function-

```swift
func handleTheOperation(input: OperationInput, context: MyApplicationContext) throws -> OperationOutput {
    return OperationOutput()
}
```

This particular operation function accepts the input to the operation and the application-specific context while
returning the output from the operation.

For HTTP1, the operation input can conform to `OperationHTTP1InputProtocol`, which defines how the input type is constructed from
the HTTP1 request. Similarly, the operation output can conform to `OperationHTTP1OutputProtocol`, which defines how to construct
the HTTP1 response from the output type. As an alternative, both operation input and output can conform to the `Codable` protocol if
they are constructed from only one part of the HTTP1 request and response.

The Smoke Framework also supports additional built-in and custom operation function signatures. See the *The Operation Function*
and *Extension Points* sections for more information.

## Step 3: Add Handler Selection

After defining the required operation handlers, it is time to specify how they are selected for incoming requests.

The Smoke Framework provides the `StandardSmokeHTTP1HandlerSelector` implementation of a Handler Selector
suitable for a basic REST-like service where operation handlers are selected based on the HTTP URI and verb
of the request.

The following code shows how to create a handler selector using the `StandardSmokeHTTP1HandlerSelector`-


```swift
import SmokeOperationsHTTP1

public typealias HandlerSelectorType =
    StandardSmokeHTTP1HandlerSelector<MyApplicationContext, JSONPayloadHTTP1OperationDelegate>

public func createHandlerSelector() -> HandlerSelectorType {
    var newHandler = HandlerSelectorType(defaultOperationDelegate: JSONPayloadHTTP1OperationDelegate())
    
    newHandler.addHandlerForUri("/theOperationPath", httpMethod: .POST,
                                operation: handleTheOperation,
                                allowedErrors: [(MyApplicationErrors.unknownResource, 400)])

    return newHandler
}
```

* `StandardSmokeHTTP1HandlerSelector` takes two generic parameters-
 * The type of the context instance to use for the application.
 * The type of the default operation delegate.
* Each handler added requires the following parameters to be specified-
 * The operation URI that must be matched by the incoming request to select the handler.
 * The HTTP method that must be matched by the incoming request to select the handler.
 * The function to be invoked.
 * The errors that can be returned to the caller from this handler.
 * The location in the HTTP1 request to construct the operation input type from (only required if the input type conforms to `Codable`)
 * The location in the HTTP1 response that the output type represents (only required if the output type conforms to `Codable`)

## Step 3: Setting up the Application Server

The final step is to setup an application as an operation server.

```swift
import Foundation
import SmokeHTTP1
import SmokeOperationsHTTP1
import LoggerAPI

// Enable logging here

let operationsContext = ... 

do {
    let smokeHTTP1Server = try SmokeHTTP1Server.startAsOperationServer(
        withHandlerSelector: createHandlerSelector(),
        andContext: operationsContext)
        
    try smokeHTTP1Server.waitUntilShutdownAndThen {
        // TODO: Close/shutdown any clients or credentials that are part
        //       of the operationsContext.
    }
} catch {
    Log.error("Unable to start Operation Server: '\(error)'")
}
```

You can now run the application and the server will start up on port 8080. The application will block in the
`smokeHTTP1Server.waitUntilShutdownAndThen` call. When the server has been fully shutdown and has
completed all requests, the closure provided to this call will be executed. In this closure you can close/shutdown
any clients or credentials that were created on startup for the operations context.

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

The Smoke Framework provides the `JSONPayloadHTTP1OperationDelegate` implementation that expects 
a JSON encoded request body as the handler's input and returns the output as the JSON encoded
response body.

Each `addHandlerForUri` invocation can optionally accept an operation delegate to use when that
handler is selected. This can be used when operations have specific encoding or decoding requirements.
A default operation delegate is set up at server startup to be used for operations without a specific
handler or when no handler matches a request.

## The Operation Function

Each handler provides a function to be invoked when the handler is selected. By default, the Smoke
framework provides four function signatures that this function can conform to-

* `((InputType, ContextType) throws -> ())`: Synchronous method with no output.
* `((InputType, ContextType) throws -> OutputType)`: Synchronous method with output.
* `((InputType, ContextType, (Swift.Error?) -> ()) throws -> ())`: Asynchronous method with no output.
* `((InputType, ContextType, (SmokeResult<OutputType>) -> ()) throws -> ())`: Asynchronous method with output.

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
* `JSONPayloadHTTP1OperationDelegate` provides basic JSON payload encoding and decoding. Instead, the `OperationDelegate` can
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
