import Foundation

// TODO: replace by sockaddr_storage

/// Undefined for LE
func htonl(_ value: UInt32) -> UInt32 {
    return value.byteSwapped
}
let ntohl = htonl

public protocol IP: CustomDebugStringConvertible {
    init?(networkBytes: Data)
    init?(_ presentation: String)
    var presentation: String { get }

    /// network-byte-order bytes
    var bytes: Data { get }
}

extension IP {
    public var debugDescription: String {
        return presentation
    }
}

// IPv4 address, wraps `in_addr`. This type is used to convert between
// human-readable presentation format and bytes in both host order and
// network order.
public struct IPv4: IP {
    /// IPv4 address in network-byte-order
    public let address: in_addr

    public init(address: in_addr) {
        self.address = address
    }

    public init?(_ presentation: String) {
        var address = in_addr()
        guard inet_pton(AF_INET, presentation, &address) == 1 else {
            return nil
        }
        self.address = address
    }

    /// network order
    public init?(networkBytes bytes: Data) {
        guard bytes.count == MemoryLayout<UInt32>.size else {
            return nil
        }
        self.address = in_addr(s_addr: UInt32(bytes: bytes.reversed()))
    }

    /// host order
    public init(_ address: UInt32) {
        self.address = in_addr(s_addr: htonl(address))
    }

    /// Format this IPv4 address using common `a.b.c.d` notation.
    public var presentationString: String? {
        let length = Int(INET_ADDRSTRLEN)
        var presentationBytes = [CChar](repeating: 0, count: length)
        var addr = self.address
        guard inet_ntop(AF_INET, &addr, &presentationBytes, socklen_t(length)) != nil else {
            return nil
        }
        return String(cString: presentationBytes)
    }

    public var presentation: String {
        return presentationString ?? "Invalid IPv4 address"
    }

    public var bytes: Data {
        return htonl(address.s_addr).bytes
    }
}

extension IPv4: Equatable, Hashable {
    // MARK: Conformance to `Hashable`

    public static func == (lhs: IPv4, rhs: IPv4) -> Bool {
        return lhs.address.s_addr == rhs.address.s_addr
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(Int(address.s_addr))
    }
}

extension IPv4: ExpressibleByIntegerLiteral {
    // MARK: Conformance to `ExpressibleByIntegerLiteral`
    public init(integerLiteral value: UInt32) {
        self.init(value)
    }
}

public struct IPv6: IP {
    public let address: in6_addr

    public init(address: in6_addr) {
        self.address = address
    }

    public init?(_ presentation: String) {
        var address = in6_addr()
        guard inet_pton(AF_INET6, presentation, &address) == 1 else {
            return nil
        }
        self.address = address
    }

    public init?(networkBytes bytes: Data) {
        guard bytes.count == MemoryLayout<in6_addr>.size else {
            return nil
        }
        address = bytes.withUnsafeBytes({ (rawBufferPointer: UnsafeRawBufferPointer) -> in6_addr in
            // Convert UnsafeRawBufferPointer to UnsafeBufferPointer<UInt8>
            let bufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
            // Convert UnsafeBufferPointer<UInt8> to UnsafePointer<UInt8>
            if let bytesPointer = bufferPointer.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: bytes.count, { return $0 }) {
                return bytesPointer.withMemoryRebound(to: in6_addr.self, capacity: 1) { $0.pointee }
            }
            return in6_addr()
        })
    }

    /// Format this IPv6 address using common `a:b:c:d:e:f:g:h` notation.
    public var presentationString: String? {
        let length = Int(INET6_ADDRSTRLEN)
        var presentationBytes = [CChar](repeating: 0, count: length)
        var addr = self.address
        guard inet_ntop(AF_INET6, &addr, &presentationBytes, socklen_t(length)) != nil else {
            return nil
        }
        return String(cString: presentationBytes)
    }

    public var presentation: String {
        return presentationString ?? "Invalid IPv6 address"
    }

    public var bytes: Data {
        #if os(Linux)
            return
                htonl(address.__in6_u.__u6_addr32.0).bytes +
                htonl(address.__in6_u.__u6_addr32.1).bytes +
                htonl(address.__in6_u.__u6_addr32.2).bytes +
                htonl(address.__in6_u.__u6_addr32.3).bytes
        #else
            return
                htonl(address.__u6_addr.__u6_addr32.0).bytes +
                htonl(address.__u6_addr.__u6_addr32.1).bytes +
                htonl(address.__u6_addr.__u6_addr32.2).bytes +
                htonl(address.__u6_addr.__u6_addr32.3).bytes
        #endif
    }
}

extension IPv6: Equatable, Hashable {
    // MARK: Conformance to `Hashable`

    public static func == (lhs: IPv6, rhs: IPv6) -> Bool {
        return lhs.presentation == rhs.presentation
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(presentation.hashValue)
    }
}
