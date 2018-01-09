import XCTest
@testable import DNS

class DNSTests: XCTestCase {
    static var allTests : [(String, (DNSTests) -> () throws -> Void)] {
        return [
            ("testReadMe", testReadMe),
            ("testPointerRecord", testPointerRecord),
            ("testMessage1", testMessage1),
            ("testMessage2", testMessage2),
            ("testMessage3", testMessage3),
            ("testMessage4", testMessage4),
            ("testMessage5", testMessage5),
            ("testDeserializeName", testDeserializeName),
            ("testDeserializeCorruptedName", testDeserializeCorruptedName),
            ("testSerializeNameCondensed", testSerializeNameCondensed),
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
        ]
    }

    func testReadMe() throws {
        // If the code below doesn't work, also update the README.md to
        // demonstrate the changes in the API.
        let request = Message(
            type: .query,
            questions: [Question(name: "apple.com.", type: .pointer)]
        )
        let requestData = try request.serialize()

        // Not shown here: send to DNS server over UDP, receive reply.
        let responseData = requestData

        // Decoding a message
        let response = try Message(deserialize: responseData)
        print(response.answers.first ?? "No answers")
    }

    func testPointerRecord() {
        var labels0 = Labels()
        var serialized0 = Data()
        let pointer0 = PointerRecord(name: "_hap._tcp.local.", ttl: 120, destination: "Swift._hap._tcp.local.")
        try! pointer0.serialize(onto: &serialized0, labels: &labels0)

        var labels1 = Labels()
        var serialized1 = Data()
        let pointer1 = PointerRecord(name: "_hap._tcp.local.", ttl: 120, destination: "Swift._hap._tcp.local.")
        try! pointer1.serialize(onto: &serialized1, labels: &labels1)

        XCTAssertEqual(serialized0.hex, serialized1.hex)

        var position = serialized0.startIndex
        let rcf = try! deserializeRecordCommonFields(serialized0, &position)
        let pointer0copy = try! PointerRecord(deserialize: serialized0, position: &position, common: rcf)

        XCTAssertEqual(pointer0, pointer0copy)
    }
    
    func testMessage1() {
        let message0 = Message(id: 4529, type: .response, operationCode: .query, authoritativeAnswer: false, truncation: false, recursionDesired: false, recursionAvailable: false, returnCode: .nonExistentDomain)
        let serialized0 = try! message0.serialize()
        XCTAssertEqual(serialized0.hex, "11b180030000000000000000")
        let message1 = try! Message(deserialize: serialized0)
        let serialized1 = try! message1.serialize()
        XCTAssertEqual(serialized0.hex, serialized1.hex)
    }

    func testMessage2() {
        let message0 = Message(id: 18765, type: .response, operationCode: .query, authoritativeAnswer: true, truncation: true, recursionDesired: true, recursionAvailable: true, returnCode: .noError)
        let serialized0 = try! message0.serialize()
        XCTAssertEqual(serialized0.hex, "494d87800000000000000000")
        let message1 = try! Message(deserialize: serialized0)
        let serialized1 = try! message1.serialize()
        XCTAssertEqual(serialized0.hex, serialized1.hex)
    }

    func testMessage3() {
        let message0 = Message(type: .query,
                               questions: [Question(name: "_airplay._tcp._local", type: .pointer)])
        let serialized0 = try! message0.serialize()
        let message1 = try! Message(deserialize: serialized0)
        let serialized1 = try! message1.serialize()
        XCTAssertEqual(serialized0.hex, serialized1.hex)
    }

    func testMessage4() {
        let service = "_airplay._tcp._local."
        let name = "example.\(service)"
        let message0 = Message(type: .response,
                               questions: [Question(name: service, type: .pointer)],
                               answers: [PointerRecord(name: service, ttl: 120, destination: name)])
        let serialized0 = try! message0.serialize()
        let message1 = try! Message(deserialize: serialized0)
        let serialized1 = try! message1.serialize()
        XCTAssertEqual(serialized0.hex, serialized1.hex)
    }

    func testMessage5() {
        let service = "_airplay._tcp._local."
        let name = "example.\(service)"
        let server = "example.local."
        let message0 = Message(type: .response,
                               questions: [Question(name: service, type: .pointer)],
                               answers: [PointerRecord(name: service, ttl: 120, destination: name),
                                         ServiceRecord(name: name, ttl: 120, port: 7000, server: server)],
                               additional: [HostRecord<IPv4>(name: server, ttl: 120, ip: IPv4("10.0.1.2")!),
                                            TextRecord(name: service, ttl: 120, attributes: ["hello": "world"])])
        let serialized0 = try! message0.serialize()
        let message1 = try! Message(deserialize: serialized0)
        let serialized1 = try! message1.serialize()
        XCTAssertEqual(serialized0.hex, serialized1.hex)
    }

    func testDeserializeName() {
        // This is part of a record. The name can be found by following two pointers indicated by 0xc000 (mask).
        let data = Data(hex: "000084000000000200000006075a6974686f656b0c5f6465766963652d696e666f045f746370056c6f63616c000010000100001194000d0c6d6f64656c3d4a3432644150085f616972706c6179c021000c000100001194000a075a6974686f656bc044")!
        var position = 89
        let name = try! deserializeName(data, &position)
        XCTAssertEqual(name, "Zithoek._airplay._tcp.local.")
        XCTAssertEqual(position, 99)
    }
    
    func testDeserializeCorruptedName() {
        let data = Data(hex: "000084000001000200009302085f616972706c6179045f746370065f6c6f63616c00000c0001c00c000c0001000000480013076578616d706c65085f616972706c6179c03ac03200210001000000780015000000001b5807656a616d706c65056c6f63616c00c057000100010000007800040a000102c00c0010000143000078000c0b68656c6c6f3d7767726c64")!
        if let _ = try? Message(deserialize: data) {
            return XCTFail("Should not have deserialized message")
        }
    }

    func testSerializeNameCondensed() {
        var message = Message(type: .response,
                              questions: [Question(name: "abc.def.ghi.jk.local.", type: .pointer)])
        let size0 = try! message.serialize().count
        XCTAssertEqual(size0, 38)
        
        message.questions.append(Question(name: "abc.def.ghi.jk.local.", type: .pointer))
        let size1 = try! message.serialize().count
        XCTAssertEqual(size1, size0 + 6)

        message.questions.append(Question(name: "def.ghi.jk.local.", type: .pointer))
        let size2 = try! message.serialize().count
        XCTAssertEqual(size2, size1 + 10)
        
        message.questions.append(Question(name: "xyz.def.ghi.jk.local.", type: .pointer))
        let size3 = try! message.serialize().count
        XCTAssertEqual(size3, size2 + 10)
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
