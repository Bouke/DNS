import XCTest

@testable import DNSTests

XCTMain([
       testCase(DNSTests.allTests),
       testCase(IPTests.allTests),
       testCase(FuzzTests.allTests)
])
