import XCTest
@testable import SmokeOperationsHTTP1Tests

XCTMain([
    testCase(SmokeOperationsHTTP1AsyncTests.allTests),
    testCase(SmokeOperationsHTTP1SyncTests.allTests),
])
