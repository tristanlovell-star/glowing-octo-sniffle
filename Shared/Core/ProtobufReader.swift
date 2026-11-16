import Foundation

enum ProtobufError: Error {
    case truncated
    case malformedVarint
    case unsupportedWireType(Int)
}

/// A tiny reader for the protobuf wire format.
///
/// Translink publishes live data as GTFS-Realtime protobuf. We only need a
/// handful of fields from it, so rather than pulling in SwiftProtobuf and
/// generated code we walk the wire format directly. Sub-readers share the
/// same underlying byte buffer (copy-on-write), so nesting is cheap.
struct ProtobufReader {
    private let bytes: [UInt8]
    private var position: Int
    private let end: Int

    init(data: Data) {
        let bytes = [UInt8](data)
        self.init(bytes: bytes, range: 0..<bytes.count)
    }

    init(bytes: [UInt8], range: Range<Int>) {
        self.bytes = bytes
        self.position = range.lowerBound
        self.end = range.upperBound
    }

    var isAtEnd: Bool { position >= end }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard position < end else { throw ProtobufError.truncated }
            let byte = bytes[position]
            position += 1
            if shift < 64 {
                result |= UInt64(byte & 0x7F) << shift
            }
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift >= 70 { throw ProtobufError.malformedVarint }
        }
    }

    /// Reads a field key. Returns the field number and wire type.
    mutating func readTag() throws -> (field: Int, wireType: Int) {
        let key = try readVarint()
        return (Int(key >> 3), Int(key & 0x7))
    }

    mutating func readInt64() throws -> Int64 {
        Int64(bitPattern: try readVarint())
    }

    mutating func readInt32() throws -> Int32 {
        Int32(truncatingIfNeeded: try readInt64())
    }

    mutating func readBool() throws -> Bool {
        try readVarint() != 0
    }

    mutating func readString() throws -> String {
        let range = try readLengthDelimitedRange()
        return String(decoding: bytes[range], as: UTF8.self)
    }

    /// Reads an embedded message and returns a reader limited to its bytes.
    mutating func readMessage() throws -> ProtobufReader {
        let range = try readLengthDelimitedRange()
        return ProtobufReader(bytes: bytes, range: range)
    }

    mutating func skipField(wireType: Int) throws {
        switch wireType {
        case 0: _ = try readVarint()
        case 1: try advance(by: 8)
        case 2: _ = try readLengthDelimitedRange()
        case 5: try advance(by: 4)
        default: throw ProtobufError.unsupportedWireType(wireType)
        }
    }

    private mutating func readLengthDelimitedRange() throws -> Range<Int> {
        let length = try readVarint()
        guard length <= UInt64(end - position) else { throw ProtobufError.truncated }
        let start = position
        position += Int(length)
        return start..<position
    }

    private mutating func advance(by count: Int) throws {
        guard end - position >= count else { throw ProtobufError.truncated }
        position += count
    }
}
