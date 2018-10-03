import XCTest
@testable import SmokeOperationsTests

XCTMain([
    testCase(SmokeOperationsAsyncTests.allTests),
    testCase(SmokeOperationsSyncTests.allTests),
])
