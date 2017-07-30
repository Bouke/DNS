import XCTest
@testable import DNS

#if os(Linux)
    import Glibc
    
    public func arc4random_uniform(_ max: UInt32) -> Int32 {
        return Glibc.rand() % Int32(max - 1)
    }
#endif

class FuzzTests: XCTestCase {
    static var allTests : [(String, (FuzzTests) -> () throws -> Void)] {
        return [
            ("testFuzzRandom", testFuzzRandom),
            ("testFuzzCorrupted", testFuzzCorrupted),
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
        ]
    }
    
    func testFuzzRandom() {
        return
        for _ in 0..<1_000_000 {
            let data = randomData()
            print(data.hex)
            do {
                _ = try Message(deserialize: data)
            } catch {
            }
        }
    }
    
    func testFuzzCorrupted() {
        return
        let service = "_airplay._tcp._local."
        let name = "example.\(service)"
        let server = "example.local."
        let message = Message(type: .response,
                              questions: [Question(name: service, type: .pointer)],
                              answers: [PointerRecord(name: service, ttl: 120, destination: name),
                                        ServiceRecord(name: name, ttl: 120, port: 7000, server: server)],
                              additional: [HostRecord<IPv4>(name: server, ttl: 120, ip: IPv4("10.0.1.2")!),
                                           TextRecord(name: service, ttl: 120, attributes: ["hello": "world"])])
        let original = try! message.serialize()
        for _ in 0..<101_000_00000 {
            var corrupted = original
            for _ in 1..<(2 + arc4random_uniform(4)) {
                let index = Data.Index(arc4random_uniform(UInt32(corrupted.endIndex)))
                switch arc4random_uniform(3) {
                case 0:
                    corrupted[index] = corrupted[index] ^ UInt8(truncatingIfNeeded: arc4random_uniform(256))
                case 1:
                    corrupted.remove(at: index)
                case 2:
                    corrupted.insert(UInt8(truncatingIfNeeded: arc4random_uniform(256)), at: index)
                default:
                    abort()
                }
            }
            print(corrupted.hex)
            do {
                _ = try Message(deserialize: corrupted)
            } catch {
            }
        }
    }
    
    // from: https://oleb.net/blog/2017/03/keeping-xctest-in-sync/#appendix-code-generation-with-sourcery
    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass
                .defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount,
                           "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }
}

func randomData() -> Data {
    let size = arc4random_uniform(32)
    return Data(bytes: (0..<size).map { _ in UInt8(truncatingIfNeeded: arc4random_uniform(256)) })
}
