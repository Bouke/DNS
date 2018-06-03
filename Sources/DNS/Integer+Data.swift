import Foundation

extension BinaryInteger {
    init(bytes: [UInt8]) {
        precondition(bytes.count == MemoryLayout<Self>.size, "incorrect number of bytes")
        self = bytes.reversed().withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) {
                return $0.pointee
            }
        }
    }

    init<S: Sequence>(bytes: S) where S.Iterator.Element == UInt8 {
        self.init(bytes: Array(bytes))
    }

    init(data: Data, position: inout Data.Index) throws {
        let start = position
        guard data.formIndex(&position, offsetBy: MemoryLayout<Self>.size, limitedBy: data.endIndex) else {
            throw DecodeError.invalidIntegerSize
        }
        let bytes = Array(Data(data[start..<position]).reversed())
        self = bytes.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: Self.self, capacity: 1) {
                return $0.pointee
            }
        }
    }
}

extension BinaryInteger {
    // returns little endian; use .bigEndian.bytes for BE.
    var bytes: Data {
        var copy = self
        return withUnsafePointer(to: &copy) {
            Data(Data(bytes: $0, count: MemoryLayout<Self>.size).reversed())
        }
    }
}
