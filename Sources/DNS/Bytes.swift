import Foundation

enum EncodeError: Swift.Error {
}

enum DecodeError: Swift.Error {
    case invalidMessageSize
    case invalidLabelSize
    case invalidLabelOffset
    case unicodeDecodingError
    case invalidIntegerSize
    case invalidIPAddress
    case invalidDataSize
}

func deserializeName(_ data: Data, _ position: inout Data.Index) throws -> String {
    var components = [String]()
    let startPosition = position
    while true {
        guard position < data.endIndex else {
            throw DecodeError.invalidLabelOffset
        }
        let step = data[position]
        if step & 0xc0 == 0xc0 {
            let offset = Int(try UInt16(data: data, position: &position) ^ 0xc000)
            guard var pointer = data.index(data.startIndex, offsetBy: offset, limitedBy: data.endIndex) else {
                throw DecodeError.invalidLabelOffset
            }
            // Prevent cyclic references
            // Its safe to assume the pointer is to an earlier label
            // See https://www.ietf.org/rfc/rfc1035.txt 4.1.4
            guard pointer < startPosition else {
                throw DecodeError.invalidLabelOffset
            }
            components += try deserializeName(data, &pointer).components(separatedBy: ".").filter({ $0 != "" })
            break
        }

        guard let start = data.index(position, offsetBy: 1, limitedBy: data.endIndex),
            let end = data.index(start, offsetBy: Int(step), limitedBy: data.endIndex) else {
            throw DecodeError.invalidLabelSize
        }
        if step > 0 {
            guard let component = String(bytes: Data(data[start..<end]), encoding: .utf8) else {
                throw DecodeError.unicodeDecodingError
            }
            components.append(component)
        }
        position = end
        if step == 0 {
            break
        }
    }
    return components.joined(separator: ".") + "."
}

public typealias Labels = [String: Data.Index]
func serializeName(_ name: String, onto buffer: inout Data, labels: inout Labels) throws {
    // re-use existing label
    if let index = labels[name] {
        buffer += (0xc000 | UInt16(index)).bytes
        return
    }
    // position of the new label
    labels[name] = buffer.endIndex
    var components = name.components(separatedBy: ".").filter { $0 != "" }
    guard !components.isEmpty else {
        buffer.append(0)
        return
    }

    let codes = Array(components.removeFirst().utf8)
    buffer.append(UInt8(codes.count))
    buffer += codes

    if components.count > 0 {
        try serializeName(components.joined(separator: "."), onto: &buffer, labels: &labels)
    } else {
        buffer.append(0)
    }
}

typealias RecordCommonFields = (name: String, type: UInt16, unique: Bool, internetClass: InternetClass, ttl: UInt32)

func deserializeRecordCommonFields(_ data: Data, _ position: inout Data.Index) throws -> RecordCommonFields {
    let name = try deserializeName(data, &position)
    let type = try UInt16(data: data, position: &position)
    let rrClass = try UInt16(data: data, position: &position)
    let internetClass = InternetClass(rrClass & 0x7fff)
    let ttl = try UInt32(data: data, position: &position)
    return (name, type, rrClass & 0x8000 == 0x8000, internetClass, ttl)
}

func serializeRecordCommonFields(_ common: RecordCommonFields, onto buffer: inout Data, labels: inout Labels) throws {
    try serializeName(common.name, onto: &buffer, labels: &labels)
    buffer.append(common.type.bytes)
    buffer.append((common.internetClass | (common.unique ? 0x8000 : 0)).bytes)
    buffer.append(common.ttl.bytes)
}

func deserializeRecord(_ data: Data, _ position: inout Data.Index) throws -> ResourceRecord {
    let common = try deserializeRecordCommonFields(data, &position)
    switch ResourceRecordType(common.type) {
    case .host: return try HostRecord<IPv4>(deserialize: data, position: &position, common: common)
    case .host6: return try HostRecord<IPv6>(deserialize: data, position: &position, common: common)
    case .service: return try ServiceRecord(deserialize: data, position: &position, common: common)
    case .text: return try TextRecord(deserialize: data, position: &position, common: common)
    case .pointer: return try PointerRecord(deserialize: data, position: &position, common: common)
    case .alias: return try AliasRecord(deserialize: data, position: &position, common: common)
    case .startOfAuthority: return try StartOfAuthorityRecord(deserialize: data, position: &position, common: common)
    default: return try Record(deserialize: data, position: &position, common: common)
    }
}

extension Message {

    // MARK: Serialization

    /// Serialize a `Message` for sending over TCP.
    ///
    /// The DNS TCP format prepends the message size before the actual
    /// message.
    ///
    /// - Returns: `Data` to be send over TCP.
    /// - Throws:
    public func serializeTCP() throws -> Data {
        let data = try serialize()
        precondition(data.count <= UInt16.max)
        return UInt16(truncatingIfNeeded: data.count).bytes + data
    }

    /// Serialize a `Message` for sending over UDP.
    ///
    /// - Returns: `Data` to be send over UDP.
    /// - Throws:
    public func serialize() throws -> Data {
        var bytes = Data()
        var labels = Labels()
        let qr: UInt16 = type == .response ? 1 : 0
        var flags: UInt16 = qr << 15
        flags |= UInt16(operationCode) << 11
        flags |= (authoritativeAnswer ? 1 : 0) << 10
        flags |= (truncation ? 1 : 0) << 9
        flags |= (recursionDesired ? 1 : 0) << 8
        flags |= (recursionAvailable ? 1 : 0) << 7
        flags |= UInt16(returnCode)

        // header
        bytes += id.bytes
        bytes += flags.bytes
        bytes += UInt16(questions.count).bytes
        bytes += UInt16(answers.count).bytes
        bytes += UInt16(authorities.count).bytes
        bytes += UInt16(additional.count).bytes

        // questions
        for question in questions {
            try serializeName(question.name, onto: &bytes, labels: &labels)
            bytes += question.type.bytes
            bytes += question.internetClass.bytes
        }

        for answer in answers {
            try answer.serialize(onto: &bytes, labels: &labels)
        }
        for authority in authorities {
            try authority.serialize(onto: &bytes, labels: &labels)
        }
        for additional in additional {
            try additional.serialize(onto: &bytes, labels: &labels)
        }

        return bytes
    }

    /// Deserializes a `Message` from a TCP stream.
    ///
    /// The DNS TCP format prepends the message size before the actual
    /// message.
    ///
    /// - Parameter bytes: the received bytes.
    /// - Throws:
    public init(deserializeTCP bytes: Data) throws {
        precondition(bytes.count >= 2)
        var position = bytes.startIndex
        let size = try Int(UInt16(data: bytes, position: &position))

        // strip size bytes (tcp only?)
        var bytes = Data(bytes[2..<2+size]) // copy? :(
        precondition(bytes.count == Int(size))

        try self.init(deserialize: bytes)
    }

    /// Deserializes a `Message` from a UDP stream.
    ///
    /// - Parameter bytes: the bytes to deserialize.
    /// - Throws:
    public init(deserialize bytes: Data) throws {
        guard bytes.count >= 12 else {
            throw DecodeError.invalidMessageSize
        }
        var position = bytes.startIndex
        id = try UInt16(data: bytes, position: &position)
        let flags = try UInt16(data: bytes, position: &position)

        type = flags >> 15 & 1 == 1 ? .response : .query
        operationCode = OperationCode(flags >> 11 & 0x7)
        authoritativeAnswer = flags >> 10 & 0x1 == 0x1
        truncation = flags >> 9 & 0x1 == 0x1
        recursionDesired = flags >> 8 & 0x1 == 0x1
        recursionAvailable = flags >> 7 & 0x1 == 0x1
        returnCode = ReturnCode(flags & 0x7)

        let numQuestions = try UInt16(data: bytes, position: &position)
        let numAnswers = try UInt16(data: bytes, position: &position)
        let numAuthorities = try UInt16(data: bytes, position: &position)
        let numAdditional = try UInt16(data: bytes, position: &position)

        questions = try (0..<numQuestions).map { _ in try Question(deserialize: bytes, position: &position) }
        answers = try (0..<numAnswers).map { _ in try deserializeRecord(bytes, &position) }
        authorities = try (0..<numAuthorities).map { _ in try deserializeRecord(bytes, &position) }
        additional = try (0..<numAdditional).map { _ in try deserializeRecord(bytes, &position) }
    }
}

extension Record: ResourceRecord {
    init(deserialize data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, type, unique, internetClass, ttl) = common
        let size = Int(try UInt16(data: data, position: &position))
        let dataStart = position
        guard data.formIndex(&position, offsetBy: size, limitedBy: data.endIndex) else {
            throw DecodeError.invalidDataSize
        }
        self.data = Data(data[dataStart..<position])
    }

    public func serialize(onto buffer: inout Data, labels: inout Labels) throws {
        try serializeRecordCommonFields((name, type, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer.append(contentsOf: UInt16(data.count).bytes + data)
    }
}

extension HostRecord: ResourceRecord {
    init(deserialize data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        let size = Int(try UInt16(data: data, position: &position))
        let dataStart = position
        guard data.formIndex(&position, offsetBy: size, limitedBy: data.endIndex) else {
            throw DecodeError.invalidDataSize
        }
        guard let ipType = IPType(networkBytes: Data(data[dataStart..<position])) else {
            throw DecodeError.invalidIPAddress
        }
        ip = ipType
    }

    public func serialize(onto buffer: inout Data, labels: inout Labels) throws {
        switch ip {
        case let ip as IPv4:
            let data = ip.bytes
            try serializeRecordCommonFields((name, ResourceRecordType.host, unique, internetClass, ttl), onto: &buffer, labels: &labels)
            buffer.append(UInt16(data.count).bytes)
            buffer.append(data)
        case let ip as IPv6:
            let data = ip.bytes
            try serializeRecordCommonFields((name, ResourceRecordType.host6, unique, internetClass, ttl), onto: &buffer, labels: &labels)
            buffer.append(UInt16(data.count).bytes)
            buffer.append(data)
        default:
            abort()
        }
    }
}

extension ServiceRecord: ResourceRecord {
    init(deserialize data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        let length = try UInt16(data: data, position: &position)
        let expectedPosition = position + Data.Index(length)
        priority = try UInt16(data: data, position: &position)
        weight = try UInt16(data: data, position: &position)
        port = try UInt16(data: data, position: &position)
        server = try deserializeName(data, &position)
        guard position == expectedPosition else {
            throw DecodeError.invalidDataSize
        }
    }

    public func serialize(onto buffer: inout Data, labels: inout Labels) throws {
        try serializeRecordCommonFields((name, ResourceRecordType.service, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer += [0, 0]
        let startPosition = buffer.endIndex
        buffer += priority.bytes
        buffer += weight.bytes
        buffer += port.bytes
        try serializeName(server, onto: &buffer, labels: &labels)

        // Set the length before the data field
        let length = UInt16(buffer.endIndex - startPosition)
        buffer.replaceSubrange((startPosition - 2)..<startPosition, with: length.bytes)
    }
}

extension TextRecord: ResourceRecord {
    init(deserialize data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        let endIndex = Int(try UInt16(data: data, position: &position)) + position

        var attrs = [String: String]()
        var other = [String]()
        while position < endIndex {
            let size = Int(try UInt8(data: data, position: &position))
            let labelStart = position
            guard size > 0 else {
                break
            }
            guard data.formIndex(&position, offsetBy: size, limitedBy: data.endIndex) else {
                throw DecodeError.invalidLabelSize
            }
            guard let label = String(bytes: Data(data[labelStart..<position]), encoding: .utf8) else {
                throw DecodeError.unicodeDecodingError
            }
            let attr = label.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map { String($0) }
            if attr.count == 2 {
                attrs[attr[0]] = attr[1]
            } else {
                other.append(attr[0])
            }
        }
        self.attributes = attrs
        self.values = other
    }

    public func serialize(onto buffer: inout Data, labels: inout Labels) throws {
        try serializeRecordCommonFields((name, ResourceRecordType.text, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        let data = attributes.reduce(Data()) {
            let attr = "\($1.key)=\($1.value)".utf8
            return $0 + UInt8(attr.count).bytes + attr
        }
        buffer += UInt16(data.count).bytes
        buffer += data
    }
}

extension PointerRecord: ResourceRecord {
    init(deserialize data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        position += 2
        destination = try deserializeName(data, &position)
    }

    public func serialize(onto buffer: inout Data, labels: inout Labels) throws {
        try serializeRecordCommonFields((name, ResourceRecordType.pointer, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer += [0, 0]
        let startPosition = buffer.endIndex
        try serializeName(destination, onto: &buffer, labels: &labels)

        // Set the length before the data field
        let length = UInt16(buffer.endIndex - startPosition)
        buffer.replaceSubrange((startPosition - 2)..<startPosition, with: length.bytes)
    }
}

extension AliasRecord: ResourceRecord {
    init(deserialize data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        position += 2
        canonicalName = try deserializeName(data, &position)
    }

    public func serialize(onto buffer: inout Data, labels: inout Labels) throws {
        try serializeRecordCommonFields((name, ResourceRecordType.alias, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer += [0, 0]
        let startPosition = buffer.endIndex
        try serializeName(canonicalName, onto: &buffer, labels: &labels)

        // Set the length before the data field
        let length = UInt16(buffer.endIndex - startPosition)
        buffer.replaceSubrange((startPosition - 2)..<startPosition, with: length.bytes)
    }
}

extension StartOfAuthorityRecord: ResourceRecord {
    init(deserialize data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        let length = try UInt16(data: data, position: &position)
        let expectedPosition = position + Data.Index(length)
        mname = try deserializeName(data, &position)
        rname = try deserializeName(data, &position)
        serial = try UInt32(data: data, position: &position)
        refresh = try Int32(data: data, position: &position)
        retry = try Int32(data: data, position: &position)
        expire = try Int32(data: data, position: &position)
        minimum = try UInt32(data: data, position: &position)
        guard position == expectedPosition else {
            throw DecodeError.invalidDataSize
        }
    }

    public func serialize(onto buffer: inout Data, labels: inout Labels) throws {
        try serializeRecordCommonFields((name, ResourceRecordType.startOfAuthority, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer += [0, 0]
        let startPosition = buffer.endIndex
        try serializeName(mname, onto: &buffer, labels: &labels)
        try serializeName(rname, onto: &buffer, labels: &labels)
        buffer += serial.bytes
        buffer += refresh.bytes
        buffer += retry.bytes
        buffer += expire.bytes
        buffer += minimum.bytes

        // Set the length before the data field
        let length = UInt16(buffer.endIndex - startPosition)
        buffer.replaceSubrange((startPosition - 2)..<startPosition, with: length.bytes)
    }
}
