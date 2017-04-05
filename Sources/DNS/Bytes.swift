import Foundation

enum EncodeError: Swift.Error {
    case unicodeEncodingNotSupported
}

enum DecodeError: Swift.Error {
    case invalidMessageSize
    case invalidOperationCode
    case invalidReturnCode
    case invalidLabelSize
    case invalidLabelOffset
    case unicodeDecodingError
    case unicodeEncodingNotSupported
    case invalidIntegerSize
    case invalidResourceRecordType
    case invalidIPAddress
    case invalidDataSize
}

func unpackName(_ data: Data, _ position: inout Data.Index) throws -> String {
    var components = [String]()
    let startPosition = position
    while true {
        let step = data[position]
        if step & 0xc0 == 0xc0 {
            let offset = Int(try UInt16(data: data, position: &position) ^ 0xc000)
            guard var pointer = data.index(data.startIndex, offsetBy: offset, limitedBy: data.endIndex) else {
                throw DecodeError.invalidLabelOffset
            }
            // Prevent cyclic references. I think it's safe to assume that label
            // pointers only point to a prior label.
            guard pointer < startPosition else {
                throw DecodeError.invalidLabelOffset
            }
            components += try unpackName(data, &pointer).components(separatedBy: ".").filter({ $0 != "" })
            break
        }

        guard let start = data.index(position, offsetBy: 1, limitedBy: data.endIndex),
            let end = data.index(start, offsetBy: Int(step), limitedBy: data.endIndex) else
        {
            throw DecodeError.invalidLabelSize
        }
        if step > 0 {
            for byte in data[start..<end] {
                guard (0x20..<0xff).contains(byte) else {
                    throw DecodeError.unicodeEncodingNotSupported
                }
            }
            guard let component = String(bytes: data[start..<end], encoding: .utf8) else {
                throw DecodeError.unicodeDecodingError
            }
            components.append(component)
        } else {
            position = end
            break
        }
        position = end
    }
    return components.joined(separator: ".") + "."
}


public typealias Labels = [String: Data.Index]
func packName(_ name: String, onto buffer: inout Data, labels: inout Labels) throws {
    if name.utf8.reduce(false, { $0 || $1 & 128 == 128 }) {
        throw EncodeError.unicodeEncodingNotSupported
    }
    // re-use existing label
    if let index = labels[name] {
        buffer += (0xc000 | UInt16(index)).bytes
        return
    }
    // position of the new label
    labels[name] = buffer.endIndex
    var components = name.components(separatedBy: ".").filter { $0 != "" }

    let codes = Array(components.removeFirst().utf8)
    buffer.append(UInt8(codes.count))
    buffer += codes

    if components.count > 0 {
        try packName(components.joined(separator: "."), onto: &buffer, labels: &labels)
    } else {
        buffer.append(0)
    }
}

func unpack<T: Integer>(_ data: Data, _ position: inout Data.Index) throws -> T {
    let size = MemoryLayout<T>.size
    defer { position += size }
    return T(bytes: data[position..<position+size])
}

typealias RecordCommonFields = (name: String, type: UInt16, unique: Bool, internetClass: UInt16, ttl: UInt32)

func unpackRecordCommonFields(_ data: Data, _ position: inout Data.Index) throws -> RecordCommonFields {
    return try (unpackName(data, &position),
                unpack(data, &position),
                data[position] & 0x80 == 0x80,
                unpack(data, &position),
                unpack(data, &position))
}

func packRecordCommonFields(_ common: RecordCommonFields, onto buffer: inout Data, labels: inout Labels) throws {
    try packName(common.name, onto: &buffer, labels: &labels)
    buffer.append(common.type.bytes)
    buffer.append((common.internetClass | (common.unique ? 0x8000 : 0)).bytes)
    buffer.append(common.ttl.bytes)
}


func unpackRecord(_ data: Data, _ position: inout Data.Index) throws -> ResourceRecord {
    let common = try unpackRecordCommonFields(data, &position)
    switch ResourceRecordType(rawValue: common.type) {
    case .host?: return try HostRecord<IPv4>(unpack: data, position: &position, common: common)
    case .host6?: return try HostRecord<IPv6>(unpack: data, position: &position, common: common)
    case .service?: return try ServiceRecord(unpack: data, position: &position, common: common)
    case .text?: return try TextRecord(unpack: data, position: &position, common: common)
    case .pointer?: return try PointerRecord(unpack: data, position: &position, common: common)
    default: return try Record(unpack: data, position: &position, common: common)
    }
}


extension Message {
    public func pack() throws -> Data {
        var bytes = Data()
        var labels = Labels()

        let flags: UInt16 = (header.response ? 1 : 0) << 15 | UInt16(header.operationCode.rawValue) << 11 | (header.authoritativeAnswer ? 1 : 0) << 10 | (header.truncation ? 1 : 0) << 9 | (header.recursionDesired ? 1 : 0) << 8 | (header.recursionAvailable ? 1 : 0) << 7 | UInt16(header.returnCode.rawValue)

        // header
        bytes += header.id.bytes
        bytes += flags.bytes
        bytes += UInt16(questions.count).bytes
        bytes += UInt16(answers.count).bytes
        bytes += UInt16(authorities.count).bytes
        bytes += UInt16(additional.count).bytes

        // questions
        for question in questions {
            try packName(question.name, onto: &bytes, labels: &labels)
            bytes += question.type.rawValue.bytes
            bytes += question.internetClass.bytes
        }

        for answer in answers {
            try answer.pack(onto: &bytes, labels: &labels)
        }
        for authority in authorities {
            try authority.pack(onto: &bytes, labels: &labels)
        }
        for additional in additional {
            try additional.pack(onto: &bytes, labels: &labels)
        }

        return bytes
    }

    public init(unpackTCP bytes: Data) throws {
        precondition(bytes.count >= 2)
        let size = Int(UInt16(bytes: bytes[0..<2]))

        // strip size bytes (tcp only?)
        var bytes = Data(bytes[2..<2+size]) // copy? :(
        precondition(bytes.count == Int(size))

        try self.init(unpack: bytes)
    }

    public init(unpack bytes: Data) throws {
        guard bytes.count >= 12 else {
            throw DecodeError.invalidMessageSize
        }
        
        let flags = UInt16(bytes: bytes[2..<4])
        guard let operationCode = OperationCode(rawValue: UInt8(flags >> 11 & 0x7)) else {
            throw DecodeError.invalidOperationCode
        }
        guard let returnCode = ReturnCode(rawValue: UInt8(flags & 0x7)) else {
            throw DecodeError.invalidReturnCode
        }

        header = Header(id: UInt16(bytes: bytes[0..<2]),
                        response: flags >> 15 & 1 == 1,
                        operationCode: operationCode,
                        authoritativeAnswer: flags >> 10 & 0x1 == 0x1,
                        truncation: flags >> 9 & 0x1 == 0x1,
                        recursionDesired: flags >> 8 & 0x1 == 0x1,
                        recursionAvailable: flags >> 7 & 0x1 == 0x1,
                        returnCode: returnCode)

        var position = bytes.index(bytes.startIndex, offsetBy: 12)

        questions = try (0..<UInt16(bytes: bytes[4..<6])).map { _ in try Question(unpack: bytes, position: &position) }
        answers = try (0..<UInt16(bytes: bytes[6..<8])).map { _ in try unpackRecord(bytes, &position) }
        authorities = try (0..<UInt16(bytes: bytes[8..<10])).map { _ in try unpackRecord(bytes, &position) }
        additional = try (0..<UInt16(bytes: bytes[10..<12])).map { _ in try unpackRecord(bytes, &position) }
    }

    func tcp() throws -> Data {
        let payload = try self.pack()
        return UInt16(payload.count).bytes + payload
    }
}

extension Record: ResourceRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, type, unique, internetClass, ttl) = common
        let size = Int(try UInt16(data: data, position: &position))
        let dataStart = position
        guard data.formIndex(&position, offsetBy: size, limitedBy: data.endIndex) else {
            throw DecodeError.invalidDataSize
        }
        self.data = Data(data[dataStart..<position])
    }

    public func pack(onto buffer: inout Data, labels: inout Labels) throws {
        try packRecordCommonFields((name, type, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer.append(contentsOf: UInt16(data.count).bytes + data)
    }
}

extension HostRecord: ResourceRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
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

    public func pack(onto buffer: inout Data, labels: inout Labels) throws {
        switch ip {
        case let ip as IPv4:
            let data = ip.bytes
            try packRecordCommonFields((name, ResourceRecordType.host.rawValue, unique, internetClass, ttl), onto: &buffer, labels: &labels)
            buffer.append(UInt16(data.count).bytes)
            buffer.append(data)
        case let ip as IPv6:
            let data = ip.bytes
            try packRecordCommonFields((name, ResourceRecordType.host6.rawValue, unique, internetClass, ttl), onto: &buffer, labels: &labels)
            buffer.append(UInt16(data.count).bytes)
            buffer.append(data)
        default:
            abort()
        }
    }
}

extension ServiceRecord: ResourceRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        let length = try UInt16(data: data, position: &position)
        let expectedPosition = position + Data.Index(length)
        priority = try unpack(data, &position)
        weight = try unpack(data, &position)
        port = try unpack(data, &position)
        server = try unpackName(data, &position)
        guard position == expectedPosition else {
            throw DecodeError.invalidDataSize
        }
    }

    public func pack(onto buffer: inout Data, labels: inout Labels) throws {
        try packRecordCommonFields((name, ResourceRecordType.service.rawValue, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer += [0, 0]
        let startPosition = buffer.endIndex
        buffer += priority.bytes
        buffer += weight.bytes
        buffer += port.bytes
        try packName(server, onto: &buffer, labels: &labels)

        // Set the length before the data field
        let length = UInt16(buffer.endIndex - startPosition)
        buffer.replaceSubrange((startPosition - 2)..<startPosition, with: length.bytes)
    }
}

extension TextRecord: ResourceRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
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
            guard let label = String(bytes: data[labelStart..<position], encoding: .utf8) else {
                throw DecodeError.unicodeDecodingError
            }
            let attr = label.characters.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map { String($0) }
            if attr.count == 2 {
                attrs[attr[0]] = attr[1]
            } else {
                other.append(attr[0])
            }
        }
        self.attributes = attrs
        self.values = other
    }

    public func pack(onto buffer: inout Data, labels: inout Labels) throws {
        try packRecordCommonFields((name, ResourceRecordType.text.rawValue, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        let data = attributes.reduce(Data()) {
            let attr = "\($1.key)=\($1.value)".utf8
            return $0 + UInt8(attr.count).bytes + attr
        }
        buffer += UInt16(data.count).bytes
        buffer += data
    }
}

extension PointerRecord: ResourceRecord {
    init(unpack data: Data, position: inout Data.Index, common: RecordCommonFields) throws {
        (name, _, unique, internetClass, ttl) = common
        position += 2
        destination = try unpackName(data, &position)
    }

    public func pack(onto buffer: inout Data, labels: inout Labels) throws {
        try packRecordCommonFields((name, ResourceRecordType.pointer.rawValue, unique, internetClass, ttl), onto: &buffer, labels: &labels)
        buffer += [0, 0]
        let startPosition = buffer.endIndex
        try packName(destination, onto: &buffer, labels: &labels)
        
        // Set the length before the data field
        let length = UInt16(buffer.endIndex - startPosition)
        buffer.replaceSubrange((startPosition - 2)..<startPosition, with: length.bytes)
    }
}
