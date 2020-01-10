import Foundation

public typealias InternetClass = UInt16

public extension InternetClass {
    static let internet: InternetClass = 1 // IN
    static let chaos: InternetClass = 3 // CH
    static let hesiod: InternetClass = 4 // HS
    static let none: InternetClass = 254
    static let any: InternetClass = 255
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
    static let host: ResourceRecordType = 0x0001
    static let nameServer: ResourceRecordType = 0x0002
    static let alias: ResourceRecordType = 0x0005
    static let startOfAuthority: ResourceRecordType = 0x0006
    static let pointer: ResourceRecordType = 0x000c
    static let mailExchange: ResourceRecordType = 0x000f
    static let text: ResourceRecordType = 0x0010
    static let host6: ResourceRecordType = 0x001c
    static let service: ResourceRecordType = 0x0021
    static let incrementalZoneTransfer: ResourceRecordType = 0x00fb
    static let standardZoneTransfer: ResourceRecordType = 0x00fc
    static let all: ResourceRecordType = 0x00ff // All cached records
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
    var name: String { get set }
    var unique: Bool { get set }
    var internetClass: InternetClass { get set }
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

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.hashValue)
    }

    public static func ==<IPType> (lhs: HostRecord<IPType>, rhs: HostRecord<IPType>) -> Bool {
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
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.hashValue)
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
    public func hash(into hasher: inout Hasher) {
        hasher.combine(destination.hashValue)
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

// https://tools.ietf.org/html/rfc1035#section-3.3.13
public struct StartOfAuthorityRecord {
    public var name: String
    public var unique: Bool
    public var internetClass: InternetClass
    public var ttl: UInt32
    public var mname: String
    public var rname: String
    public var serial: UInt32
    public var refresh: Int32
    public var retry: Int32
    public var expire: Int32
    public var minimum: UInt32

    public init(name: String, unique: Bool = false, internetClass: InternetClass = .internet, ttl: UInt32, mname: String, rname: String, serial: UInt32, refresh: Int32, retry: Int32, expire: Int32, minimum: UInt32) {
        self.name = name
        self.unique = unique
        self.internetClass = internetClass
        self.ttl = ttl
        self.mname = mname
        self.rname = rname
        self.serial = serial
        self.refresh = refresh
        self.retry = retry
        self.expire = expire
        self.minimum = minimum
    }
}
