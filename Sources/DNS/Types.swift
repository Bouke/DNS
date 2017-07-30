import Foundation

public enum MessageType { // 1 bit
    case query
    case response
}

/// All communications inside of the domain protocol are carried in a single
/// format called a message.  The top level format of message is divided
/// into 5 sections (some of which are empty in certain cases) shown below:
///
///     +---------------------+
///     |        Header       |
///     +---------------------+
///     |       Question      | the question for the name server
///     +---------------------+
///     |        Answer       | RRs answering the question
///     +---------------------+
///     |      Authority      | RRs pointing toward an authority
///     +---------------------+
///     |      Additional     | RRs holding additional information
///     +---------------------+
///
/// The header section is always present.  The header includes fields that
/// specify which of the remaining sections are present, and also specify
/// whether the message is a query or a response, a standard query or some
/// other opcode, etc.
///
/// The names of the sections after the header are derived from their use in
/// standard queries.  The question section contains fields that describe a
/// question to a name server.  These fields are a query type (QTYPE), a
/// query class (QCLASS), and a query domain name (QNAME).  The last three
/// sections have the same format: a possibly empty list of concatenated
/// resource records (RRs).  The answer section contains RRs that answer the
/// question; the authority section contains RRs that point toward an
/// authoritative name server; the additional records section contains RRs
/// which relate to the query, but are not strictly answers for the
/// question.
public struct Message {

    // MARK: Message header section

    /// A 16 bit identifier assigned by the program that
    /// generates any kind of query.  This identifier is copied
    /// the corresponding reply and can be used by the requester
    /// to match up replies to outstanding queries.
    public var id: UInt16

    /// A one bit field that specifies whether this message is a
    /// query (0), or a response (1).
    public var type: MessageType

    /// A four bit field that specifies kind of query in this
    /// message.  This value is set by the originator of a query
    /// and copied into the response.  The values are:
    public var operationCode: OperationCode

    /// Authoritative Answer - this bit is valid in responses,
    /// and specifies that the responding name server is an
    /// authority for the domain name in question section.
    ///
    /// Note that the contents of the answer section may have
    /// multiple owner names because of aliases.  The AA bit
    /// corresponds to the name which matches the query name, or
    /// the first owner name in the answer section.
    public var authoritativeAnswer: Bool

    /// TrunCation - specifies that this message was truncated
    /// due to length greater than that permitted on the
    /// transmission channel.
    public var truncation: Bool

    /// Recursion Desired - this bit may be set in a query and
    /// is copied into the response.  If RD is set, it directs
    /// the name server to pursue the query recursively.
    /// Recursive query support is optional.
    public var recursionDesired: Bool

    /// Recursion Available - this be is set or cleared in a
    /// response, and denotes whether recursive query support is
    /// available in the name server.
    public var recursionAvailable: Bool

    /// Response code - this 4 bit field is set as part of
    /// responses.
    public var returnCode: ReturnCode

    // MARK: Other sections

    /// Question section.
    public var questions: [Question]

    /// Answer section.
    public var answers: [ResourceRecord]

    /// Authority section.
    public var authorities: [ResourceRecord]

    /// Additional records section.
    public var additional: [ResourceRecord]

    // MARK: Initializing

    /// Create a `Message` instance.
    ///
    /// To create a query:
    ///
    /// ```swift
    /// let query = Message(
    ///     id: UInt16(extendingOrTruncating: arc4random()),
    ///     type: .query,
    ///     questions: [
    ///         Question(name: "apple.com", type: .host)
    ///     ])
    /// ```
    ///
    /// To create a response for this query:
    ///
    /// ```swift
    /// let response = Message(
    ///     id: query.id,
    ///     type: .response,
    ///     returnCode: .noError,
    ///     questions: query.questions,
    ///     answers: [
    ///         HostRecord<IPv4>(name: "apple.com", ttl: 3600, ip: IPv4("17.172.224.47")!)
    ///     ])
    /// ```
    ///
    /// - Parameters:
    ///   - id:
    ///   - type:
    ///   - operationCode:
    ///   - authoritativeAnswer:
    ///   - truncation:
    ///   - recursionDesired:
    ///   - recursionAvailable:
    ///   - returnCode:
    ///   - questions:
    ///   - answers:
    ///   - authorities:
    ///   - additional:
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
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        switch type {
        case .query: return "DNS Request(id: \(id), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable), questions: \(questions), answers: \(answers), authorities: \(authorities), additional: \(additional))"
        case .response: return "DNS Response(id: \(id), returnCode: \(returnCode), authoritativeAnswer: \(authoritativeAnswer), truncation: \(truncation), recursionDesired: \(recursionDesired), recursionAvailable: \(recursionAvailable), questions: \(questions), answers: \(answers), authorities: \(authorities), additional: \(additional))"
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

    init(deserialize data: Data, position: inout Data.Index) throws {
        name = try deserializeName(data, &position)
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

    func serialize(onto: inout Data, labels: inout Labels) throws
}


public struct Record {
    public var name: String
    public var type: UInt16
    public var internetClass: InternetClass
    public var unique: Bool
    public var ttl: UInt32
    public var data: Data

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
