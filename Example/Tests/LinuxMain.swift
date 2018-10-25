import XCTest

import SmokeAPITests

var tests = [XCTestCaseEntry]()
tests += SmokeAPITests.allTests()
XCTMain(tests)