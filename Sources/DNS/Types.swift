import Foundation

public enum MessageType { // 1 bit
    case query
    case response
}

public struct Message {
    public var id: UInt16
    public var type: MessageType
    public var operationCode: OperationCode
    public var authoritativeAnswer: Bool
    public var truncation: Bool
    public var recursionDesired: Bool
    public var recursionAvailable: Bool
    public var returnCode: ReturnCode

    public var questions: [Question]
    public var answers: [ResourceRecord]
    public var authorities: [ResourceRecord]
    public var additional: [ResourceRecord]

    public init(
        id: UInt16 = 0,
        type: MessageType,
        operationCode: OperationCode = .query,
        authoritativeAnswer: Bool = true,
        truncation: Bool = false,
        recursionDesired: Bool = false,
        recursionAvailable: Bool = false,
        returnCode: ReturnCode = .noError,
        questions: [Question] = [],
        answers: [ResourceRecord] = [],
        authorities: [ResourceRecord] = [],
        additional: [ResourceRecord] = []
    ) {
        self.id = id
        self.type = type
        self.operationCode = operationCode
        self.authoritativeAnswer = authoritativeAnswer
        self.truncation = truncation
        self.recursionDesired = recursionDesired
        self.recursionAvailable = recursionAvailable
        self.returnCode = returnCode

        self.questions = questions
        self.answers = answers
        self.authorities = authorities
        self.additional = additional
    }
}

extension Message: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch type {
        case .query: return "DNS Request(id: \(id), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable))"
        case .response: return "DNS Response(id: \(id), returnCode: \(returnCode), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable))"
        }
    }
}

public typealias OperationCode = UInt8

public extension OperationCode { // 4 bits: 0-15
    public static let query: OperationCode = 0 // QUERY
    public static let inverseQuery: OperationCode = 1 // IQUERY
    public static let statusRequest: OperationCode = 2 // STATUS
    public static let notify: OperationCode = 4 // NOTIFY
    public static let update: OperationCode = 5 // UPDATE
}

public typealias ReturnCode = UInt8

public extension ReturnCode { // 4 bits: 0-15
    public static let noError: ReturnCode = 0 // NOERROR
    public static let formatError: ReturnCode = 1 // FORMERR
    public static let serverFailure: ReturnCode = 2 // SERVFAIL
    public static let nonExistentDomain: ReturnCode = 3 // NXDOMAIN
    public static let notImplemented: ReturnCode = 4 // NOTIMPL
    public static let queryRefused: ReturnCode = 5 // REFUSED
    public static let nameExistsWhenItShouldNot: ReturnCode = 6 // YXDOMAIN
    public static let rrSetExistsWhenItShouldNot: ReturnCode = 7 // YXRRSET
    public static let rrSetThatShouldExistDoestNot: ReturnCode = 8 // NXRRSET
    public static let serverNotAuthoritativeForZone: ReturnCode = 9 // NOTAUTH
    public static let nameNotContainedInZone: ReturnCode = 10 // NOTZONE
}

public typealias InternetClass = UInt16

public extension InternetClass {
    public static let internet: InternetClass = 1 // IN
    public static let chaos: InternetClass = 3 // CH
    public static let hesiod: InternetClass = 4 // HS
    public static let none: InternetClass = 254
    public static let any: InternetClass = 255
}

public struct Question {
    public var name: String
    public var type: ResourceRecordType
    public var unique: Bool
    public var internetClass: InternetClass

    public init(name: String, type: ResourceRecordType, unique: Bool = false, internetClass: InternetClass = .internet) {
        self.name = name
        self.type = type
        self.unique = unique
        self.internetClass = internetClass
    }

    init(unpack data: Data, position: inout Data.Index) throws {
        name = try unpackName(data, &position)
        type = try ResourceRecordType(data: data, position: &position)
        unique = data[position] & 0x80 == 0x80
        let rawInternetClass = try UInt16(data: data, position: &position)
        internetClass = InternetClass(rawInternetClass & 0x7fff)
    }
}

public typealias ResourceRecordType = UInt16

public extension ResourceRecordType {
    public static let host: ResourceRecordType = 0x0001
    public static let nameServer: ResourceRecordType = 0x0002
    public static let alias: ResourceRecordType = 0x0005
    public static let startOfAuthority: ResourceRecordType = 0x0006
    public static let pointer: ResourceRecordType = 0x000c
    public static let mailExchange: ResourceRecordType = 0x000f
    public static let text: ResourceRecordType = 0x0010
    public static let host6: ResourceRecordType = 0x001c
    public static let service: ResourceRecordType = 0x0021
    public static let incrementalZoneTransfer: ResourceRecordType = 0x00fb
    public static let standardZoneTransfer: ResourceRecordType = 0x00fc
    public static let all: ResourceRecordType = 0x00ff // All cached records
}

extension ResourceRecordType: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .host: return "A"
        case .nameServer: return "NS"
        case .alias: return "CNAME"
        case .startOfAuthority: return "SOA"
        case .pointer: return "PTR"
        case .mailExchange: return "MX"
        case .text: return "TXT"
        case .host6: return "AAAA"
        case .service: return "SRV"
        case .incrementalZoneTransfer: return "IXFR"
        case .standardZoneTransfer: return "AXFR"
        case .all: return "*"
        default: return "Unknown"
        }
    }
}


public protocol ResourceRecord {
    var name: String { get }
    var unique: Bool { get }
    var internetClass: InternetClass { get }
    var ttl: UInt32 { get set }

    func pack(onto: inout Data, labels: inout Labels) throws
}


public struct Record {
    public var name: String
    public var type: UInt16
    public var internetClass: InternetClass
    public var unique: Bool
    public var ttl: UInt32
    var data: Data

    public init(name: String, type: UInt16, internetClass: InternetClass, unique: Bool, ttl: UInt32, data: Data) {
        self.name = name
        self.type = type
        self.internetClass = internetClass
        self.unique = unique
        self.ttl = ttl
        self.data = data
    }
}


public struct HostRecord<IPType: IP> {
    public var name: String
    public var unique: Bool
    public var internetClass: InternetClass
    public var ttl: UInt32
    public var ip: IPType

    public init(name: String, unique: Bool = false, internetClass: InternetClass = .internet, ttl: UInt32, ip: IPType) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.ip = ip
    }
}


extension HostRecord: Hashable {
    public var hashValue: Int {
        return name.hashValue
    }

    public static func ==<IPType: IP> (lhs: HostRecord<IPType>, rhs: HostRecord<IPType>) -> Bool {
        return lhs.name == rhs.name
        // TODO: check equality of IP addresses
    }
}


public struct ServiceRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: InternetClass
    public var ttl: UInt32
    public var priority: UInt16
    public var weight: UInt16
    public var port: UInt16
    public var server: String

    public init(name: String, unique: Bool = false, internetClass: InternetClass = .internet, ttl: UInt32, priority: UInt16 = 0, weight: UInt16 = 0, port: UInt16, server: String) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.priority = priority
        self.weight = weight
        self.port = port
        self.server = server
    }
}


extension ServiceRecord: Hashable {
    public var hashValue: Int {
        return name.hashValue
    }

    public static func == (lhs: ServiceRecord, rhs: ServiceRecord) -> Bool {
        return lhs.name == rhs.name
    }
}


public struct TextRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: InternetClass
    public var ttl: UInt32
    public var attributes: [String: String]
    public var values: [String]

    public init(name: String, unique: Bool = false, internetClass: InternetClass = .internet, ttl: UInt32, attributes: [String: String]) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.attributes = attributes
        self.values = []
    }
}


public struct PointerRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: InternetClass
    public var ttl: UInt32
    public var destination: String

    public init(name: String, unique: Bool = false, internetClass: InternetClass = .internet, ttl: UInt32, destination: String) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.destination = destination
    }
}


extension PointerRecord: Hashable {
    public var hashValue: Int {
        return destination.hashValue
    }

    public static func == (lhs: PointerRecord, rhs: PointerRecord) -> Bool {
        return lhs.name == rhs.name && lhs.destination == rhs.destination
    }
}


public struct AliasRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: InternetClass
    public var ttl: UInt32
    public var canonicalName: String
}
