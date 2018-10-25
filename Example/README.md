## How to make a simple Post request with Smoke-Framework

### Start
First of all, open terminal and create a new empty folder.

Create an executable package by running the following commands in the terminal:
`swift package init --type executable`

Open `Package.swift` file and add `smoke-framework` into dependencies section and also update targets dependencies:

```swift
let package = Package(
name: "Smoke",
dependencies: [
// Dependencies declare other packages that this package depends on.
// .package(url: /* package url */, from: "1.0.0"),
.package(url: "https://github.com/amzn/smoke-framework.git", .upToNextMajor(from: "0.6.0"))
],
targets: [
// Targets are the basic building blocks of a package. A target can define a module or a test suite.
// Targets can depend on other targets in this package, and on products in packages which this package depends on.
.target(
name: "Smoke",
dependencies: ["smoke-framework"]),
.testTarget(
name: "SmokeTests",
dependencies: ["Smoke"]),
]
)
```

### Build

Back to termial and type `swift build`. This command will fetch `Smoke-framework` for you into this folder as well as those dependencies `Smoke-framework` needs. 

You will see `main.swift` file locates in `Sources/SmokeAPI` and if you open it there will be only one line `print("Hello, world!")`

In this example, there are a few files which are absctracted from test cases in `Smoke-framework`.

`main` sets up the `post` call and it will start service 
`ExampleInput` defines input data structure
`ExampleError` defines errors 
`ExampleOutput` defines output structure

### Run

Type `swift run SmokeAPI` in termial, it will run main file and start service.

### Test

You can either test it in your own project with HTTP request or test it with some tools like postman.
Here's the screenshot of testing it with postman


