---
date: 2022-10-28 14:00
description: A detailed discussion of the role of the Context Type within the smoke-framework and how it should be used.
tags: SmokeFramework, context type
---
# The Context Type

The Context Type is a foundational concept of the smoke-framework. The Context Type is designed to provide access to all the *things* an operation handler
may want to access during that operation's execution. These *things* may include-

1. Service Clients
2. Helper objects such as loggers
3. Injected logic that is dependent on the higher level environment

By default, the instances of the Context Type will be request-scoped - it will be created when a request is received by the framework and will live until 
the request is fully processed. The Context Type is thus named because it represents the *context* in which the request is being processed by the 
operation handler.

## Defining the Request Type

Applications initialized using `smoke-framework-application-generate` will be created with a stub definition
of the Context Type-

```
public struct MyServiceOperationsContext {
    let logger: Logger
    // TODO: Add properties to be accessed by the operation handlers
    
    public init(logger: Logger) {
        self.logger = logger
    }
}
```

The following sections will discuss how to add particular types of instances to the Context Type.

### Helper objects

Helper objects such as loggers are pretty straight forward to add to the context type as typically it is always the same concrete type.
The stub Context Type created when using `smoke-framework-application-generate` already adds the logger. Other helper objects can be added
in the same way.

```
public struct MyServiceOperationsContext {
    let logger: Logger
    let myHelperObject: MyHelperObject
    
    public init(logger: Logger,
                myHelperObject: MyHelperObject) {
        self.logger = logger
        self.myHelperObject = myHelperObject
    }
}
```

In your application handler you can then make use of this helper instance-

```
extension MyServiceOperationsContext {
    public func handleHasSubscriptions(input: MyServiceModel.HasSubscriptionsRequest) async throws
    -> MyServiceModel.HasSubscriptionsResponse {
        self.myHelperObject.doTheThing()
                
        return HasSubscriptionsResponse(hasSubscriptions: false)
    }
}
```

You will then have to update the application's initializer to provide an instance appropriate to each request.

For unit tests, you will also need to provide an instance appropriate to each unit test.

```
func createOperationsContext(myHelperObject myHelperObjectOptional: MyHelperObject? = nil) 
-> MyServiceOperationsContext {
    let myHelperObject = myHelperObjectOptional ?? getDefaultMyHelperObjectForTesting()
    
    return MyServiceOperationsContext(logger: TestVariables.logger,
                                      myHelperObject: myHelperObject)
}
```

### Service Clients

Services clients are potentially more complicated from standard helper objects as the concrete type you want to use
may differ between unit tests and the standard operation of the service. You may want to use some service mock for
unit tests.

There are two approaches to including such service clients in the Context Type. Both require having a protocol that
the concrete types will conform to.

The first approach is the simplest and involves using the protocol directly in the Context Type.

```
public struct MyServiceOperationsContext {
    let otherClient: any OtherClientProtocol
    let logger: Logger

    public init(otherClient: any OtherClientProtocol,
                logger: Logger) {
        self.otherClient = otherClient
        self.logger = logger
    }
}
```

In your application handler you can then make use of this client instance-

```
extension MyServiceOperationsContext {
    public func handleHasSubscriptions(input: MyServiceModel.HasSubscriptionsRequest) async throws
    -> MyServiceModel.HasSubscriptionsResponse {
        let listSubscriptionsResponse = try await self.otherClient.listSubscriptions(input: ListSubscriptionsRequest())
        
        return HasSubscriptionsResponse(hasSubscriptions: !listSubscriptionsResponse.subscriptions.isEmpty)
    }
}
```

At runtime, the instance of the Context Type will contain an existential box that will then contain a reference to the actual
concrete type. This is an additional layer of redirection that will occur whenever the service client instance is called in
the operation handler.

The second approach is more efficient but may require more consideration when passing around the Context Type. This approach
makes the Context Type *generic* with respect to the concrete client type.


```
public struct MyServiceOperationsContext<OtherClientType: OtherClientProtocol> {
    let otherClient: OtherClientType
    let logger: Logger

    public init(otherClient: OtherClientType,
                logger: Logger) {
        self.otherClient = otherClient
        self.logger = logger
    }
}
```

At runtime, the instance of the Context Type will reference the actual concrete type of the client directly.

For applications using build-time code generation using `smoke-framework-application-generate`, this will require additional
configuration in `smoke-framework-codegen.json` to define the concrete type used when the service is being run-

```
  "integrations": {
      "http": {
          "contextTypeName": "HTTPMyServiceOperationsContext"
      }
  },
```

This concrete type is typically defined using a typedef in the HTTP1 integration package-

```
public typealias HTTPMyServiceOperationsContext =
    MyServiceOperationsContext<APIGatewayOtherClient>
```

Unit tests are then free to use whatever concrete type they require-

```
func createOperationsContext(otherClient otherClientOptional: MockOtherClient? = nil)
-> MyServiceOperationsContext<MockOtherClient> {
    let otherClient = otherClientOptional ?? MockOtherClient()
    
    return MyServiceOperationsContext(otherClient: otherClient,
                                      logger: TestVariables.logger)
}
```

In your application handler you can then make use of this client instance in the same way as for approach one except if 
you want to pass the Context Type (or the client instance itself) to other functions. These functions will themselves have to become generic.

```
extension MyServiceOperationsContext {
    public func handleHasSubscriptions(input: MyServiceModel.HasSubscriptionsRequest) async throws
    -> MyServiceModel.HasSubscriptionsResponse {
        return try await hasSubscriptionsLogic(context: self)
    }
}

private func hasSubscriptionsLogic<OtherClientType: OtherClientProtocol>(
    context: MyServiceOperationsContext<OtherClientType>) async throws
-> MyServiceModel.HasSubscriptionsResponse {
    let listSubscriptionsResponse = try await context.otherClient.listSubscriptions(input: ListSubscriptionsRequest())
    
    return HasSubscriptionsResponse(hasSubscriptions: !listSubscriptionsResponse.subscriptions.isEmpty)
}
```

### Injected logic

The final use for the Context Type is to inject logic for an operation handler to use that is different for different environments.
An example of this is logic to generate a unique component of an identifier. When the service is running, you would want to generate a 
different component for each identifier (such as a uuid) but for unit tests you may want to know exactly what component was being used.

To provide such logic you can add a helper object or a function type directly to the Context Type.

```
public struct MyServiceOperationsContext {
    let logger: Logger
    let idGenerator: () -> String
    
    public init(logger: Logger,
                idGenerator: @escaping () -> String) {
        self.logger = logger
        self.idGenerator = idGenerator
    }
}
```

```
extension MyServiceOperationsContext {
    public func handleGenerateSubscriptionId(input: MyServiceModel.GenerateSubscriptionIdRequest) async throws
    -> MyServiceModel.GenerateSubscriptionIdResponse {
        let newId = idPrefix + self.idGenerator()
        
        return GenerateSubscriptionIdResponse(subscriptionId: newId)
    }
}
```

You can then instantiate an instance of the Context Type as appropriate for different environments.

## A Request Scoped Context Type

The default configuration for the smoke-framework is that the Context Type will be request scoped; that is a new instance of the Context Type
will be created for each incoming request.

Applications initialized using [smoke-framework-application-generate](https://github.com/amzn/smoke-framework-application-generate)
will create an application initializer of the form-

```
@main
struct MyServicePerInvocationContextInitializer: MyServicePerInvocationContextInitializerProtocol {
    // application-scoped instances

    /**
     On application startup.
     */
    init(eventLoopGroup: EventLoopGroup) async throws {
        // initialize application-scoped instances
    }

    /**
     On invocation.
    */
    public func getInvocationContext(invocationReporting: SmokeServerInvocationReporting<SmokeInvocationTraceContext>)
    -> MyServiceOperationsContext {
        // will be called once per request
        // create an instance of the Context Type using the invocationReporting instance provided
        // or an application-scoped instances
        
        return MyServiceOperationsContext(...)
    }

    /**
     On application shutdown.
    */
    func onShutdown() async throws {
        // cleanup any application-scoped instances
    }
}
```

This initializer provides opportunities to create application-scoped instances (that are created once upon application start up)
and then to clean them up when the application is shutting down. It also provides an opportunity to create request-scoped instances 
(that are created once per request) and make them available to operation handlers.

## Thread Safety

If parts of your operation handlers execute concurrently (either using Swift Concurrency or EventLoopFutures), the Context Type will
definitely have to be thread safe. In the future, Swift Concurrency will enforce that the Context Type conform to `Sendable` if it is being
passed across concurrency boundaries within your operation handler.

Any instance that is shared between instances of a request-scoped Context Type (such as a class) will also have to be thread safe as multiple requests
may be executed concurrently.

A Context Type should just have immutable value types if possible.

## Extensions on the Context Type

Applications initialized using `smoke-framework-application-generate` will generate operation handler stubs that are within extensions of the Context
Type. Conceptually these operation handlers are related to the Context Type because they execute within the *context* of the request.

```
extension MyServiceOperationsContext {
    public func handleHasSubscriptions(input: MyServiceModel.HasSubscriptionsRequest) async throws
    -> MyServiceModel.HasSubscriptionsResponse {
        let listSubscriptionsResponse = try await self.otherClient.listSubscriptions(input: ListSubscriptionsRequest())
        
        return HasSubscriptionsResponse(hasSubscriptions: !listSubscriptionsResponse.subscriptions.isEmpty)
    }
}
```

Helper functions called by the operation handler functions that also execute within the same context should also be specified 
within extensions of the Context Type. Access control levels can be used to limit the visibility of functions on the Context Type; ie. functions can
be made `private` if they are solely going to be used within their declaring file and `internal` or `public` if they could be
called more broadly such as by multiple operation handlers.

Exceptions to declaring helper functions on the Context Type are when a function has a *stronger* association with another type.

For instance, some functions may form a pseudo API on a service client, providing functionality tightly related to that remote service (but maybe 
too specific to the consuming service to actually be a formal API of the service). In these cases it may make more sense for such 
functions to be declared as extensions on the service client itself.

Functions can also be declared in extensions on model types - such as operation Input and Output types if the functionality they are performing
is primarily associated with that type (such as instantiating the type or transforming the type into another type).
