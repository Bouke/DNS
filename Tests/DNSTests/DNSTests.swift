import XCTest
@testable import DNS

class DNSTests: XCTestCase {
    static var allTests : [(String, (DNSTests) -> () throws -> Void)] {
        return [
            ("testPointerRecord", testPointerRecord),
            ("testMessage1", testMessage1),
            ("testMessage2", testMessage2),
            ("testMessage3", testMessage3),
            ("testMessage4", testMessage4),
            ("testMessage5", testMessage5),
            ("testUnpackName", testUnpackName),
        ]
    }

    func testPointerRecord() {
        var labels0 = Labels()
        var packed0 = Data()
        let pointer0 = PointerRecord(name: "_hap._tcp.local.", ttl: 120, destination: "Swift._hap._tcp.local.")
        try! pointer0.pack(onto: &packed0, labels: &labels0)

        var labels1 = Labels()
        var packed1 = Data()
        let pointer1 = PointerRecord(name: "_hap._tcp.local", ttl: 120, destination: "Swift._hap._tcp.local")
        try! pointer1.pack(onto: &packed1, labels: &labels1)

        XCTAssertEqual(packed0.hex, packed1.hex)

        var position = packed0.startIndex
        let rcf = unpackRecordCommonFields(packed0, &position)
        let pointer0copy = PointerRecord(unpack: packed0, position: &position, common: rcf)

        XCTAssertEqual(pointer0, pointer0copy)
    }
    
    func testMessage1() {
        let message0 = Message(header: Header(id: 4529, response: true, operationCode: .query, authoritativeAnswer: false, truncation: false, recursionDesired: false, recursionAvailable: false, returnCode: .NXDOMAIN))
        let packed0 = try! message0.pack()
        XCTAssertEqual(packed0.hex, "11b180030000000000000000")
        let message1 = Message(unpack: packed0)
        let packed1 = try! message1.pack()
        XCTAssertEqual(packed0.hex, packed1.hex)
    }

    func testMessage2() {
        let message0 = Message(header: Header(id: 18765, response: true, operationCode: .query, authoritativeAnswer: true, truncation: true, recursionDesired: true, recursionAvailable: true, returnCode: .NOERROR))
        let packed0 = try! message0.pack()
        XCTAssertEqual(packed0.hex, "494d87800000000000000000")
        let message1 = Message(unpack: packed0)
        let packed1 = try! message1.pack()
        XCTAssertEqual(packed0.hex, packed1.hex)
    }

    func testMessage3() {
        let message0 = Message(header: Header(response: false),
                               questions: [Question(name: "_airplay._tcp._local", type: .pointer)])
        let packed0 = try! message0.pack()
        let message1 = Message(unpack: packed0)
        let packed1 = try! message1.pack()
        XCTAssertEqual(packed0.hex, packed1.hex)
    }

    func testMessage4() {
        let service = "_airplay._tcp._local."
        let name = "example.\(service)"
        let message0 = Message(header: Header(response: true),
                               questions: [Question(name: service, type: .pointer)],
                               answers: [PointerRecord(name: service, ttl: 120, destination: name)])
        let packed0 = try! message0.pack()
        let message1 = Message(unpack: packed0)
        let packed1 = try! message1.pack()
        XCTAssertEqual(packed0.hex, packed1.hex)
    }

    func testMessage5() {
        let service = "_airplay._tcp._local."
        let name = "example.\(service)"
        let server = "example.local."
        let message0 = Message(header: Header(response: true),
                               questions: [Question(name: service, type: .pointer)],
                               answers: [PointerRecord(name: service, ttl: 120, destination: name),
                                         ServiceRecord(name: name, ttl: 120, port: 7000, server: server)],
                               additional: [HostRecord<IPv4>(name: server, ttl: 120, ip: IPv4("10.0.1.2")!),
                                            TextRecord(name: service, ttl: 120, attributes: ["hello": "world"])])
        let packed0 = try! message0.pack()
        let message1 = Message(unpack: packed0)
        let packed1 = try! message1.pack()
        XCTAssertEqual(packed0.hex, packed1.hex)
    }

    func testUnpackName() {
        // This is part of a record. The name can be found by following two pointers indicated by 0xc000 (mask).
        let data = Data(hex: "000084000000000200000006075a6974686f656b0c5f6465766963652d696e666f045f746370056c6f63616c000010000100001194000d0c6d6f64656c3d4a3432644150085f616972706c6179c021000c000100001194000a075a6974686f656bc044")!
        var position = 89
        let name = unpackName(data, &position)
        XCTAssertEqual(name, "Zithoek._airplay._tcp.local.")
        XCTAssertEqual(position, 99)
    }
}
