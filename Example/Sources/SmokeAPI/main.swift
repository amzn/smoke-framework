
import Foundation
import SmokeHTTP1
import SmokeOperations
import LoggerAPI

struct MyApplicationContext {}

typealias HandlerSelectorType =
    StandardSmokeHTTP1HandlerSelector<MyApplicationContext, JSONPayloadHTTP1OperationDelegate>

func handleExampleOperationAsync(input: ExampleInput, context: MyApplicationContext,
                                 responseHandler: (SmokeResult<ExampleOutput>) -> ()) throws {
    
    let attributes = ExampleOutput(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                      isGreat: true)
    
    responseHandler(.response(attributes))
}

let allowedErrors = [(MyError.theError(reason: "MyError"), 400)]

func createHandlerSelector() -> HandlerSelectorType {
    
    var newHandlerSelector = HandlerSelectorType()
    
    newHandlerSelector.addHandlerForUri("/postexample", httpMethod: .POST,
                                        handler: OperationHandler(operation: handleExampleOperationAsync,
                                                                  allowedErrors: allowedErrors))
    
    return newHandlerSelector
}

do {
    try SmokeHTTP1Server.startAsOperationServer(
        withHandlerSelector: createHandlerSelector(),
        andContext: MyApplicationContext(),
        defaultOperationDelegate: JSONPayloadHTTP1OperationDelegate())
} catch {
    Log.error("Unable to start Operation Server: '\(error)'")
}
