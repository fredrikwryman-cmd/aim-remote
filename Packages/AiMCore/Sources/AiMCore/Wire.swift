import Foundation

public enum WireError: Error { case malformed, oversized, unexpectedMessage }

/// The subset of protobuf wire types used by Android TV Remote v2.
/// Unknown fixed32/fixed64 fields are skipped for forward compatibility.
public struct Proto {
    public private(set) var integers: [Int: UInt64] = [:]
    public private(set) var bytes: [Int: [Data]] = [:]
    public init(_ data: Data) throws {
        let input = [UInt8](data)
        var i = 0
        while i < input.count {
            guard let tag = try Self.readVarint(input, &i), tag >> 3 > 0,
                  tag >> 3 <= 536_870_911 else { throw WireError.malformed }
            let field = Int(tag >> 3)
            switch tag & 7 {
            case 0:
                guard let n = try Self.readVarint(input, &i) else { throw WireError.malformed }
                integers[field] = n
            case 2:
                guard let n = try Self.readVarint(input, &i), n <= UInt64(input.count - i) else {
                    throw WireError.malformed
                }
                let end = i + Int(n)
                bytes[field, default: []].append(Data(input[i..<end]))
                i = end
            case 1, 5:
                let length = (tag & 7) == 1 ? 8 : 4
                guard input.count - i >= length else { throw WireError.malformed }
                i += length
            default: throw WireError.malformed
            }
        }
    }
    public func number(_ field: Int) -> UInt64 { integers[field] ?? 0 }
    public func child(_ field: Int) throws -> Proto? {
        try bytes[field]?.first.map { try Proto($0) }
    }
    public func string(_ field: Int) -> String? {
        bytes[field]?.first.flatMap { String(data: $0, encoding: .utf8) }
    }
    public static func varint(_ value: UInt64) -> Data {
        var n = value, out = Data()
        repeat {
            var byte = UInt8(n & 127)
            n >>= 7
            if n != 0 { byte |= 128 }
            out.append(byte)
        } while n != 0
        return out
    }
    public static func uint(_ field: Int, _ n: UInt64) -> Data {
        varint(UInt64(field << 3)) + varint(n)
    }
    public static func blob(_ field: Int, _ data: Data) -> Data {
        varint(UInt64((field << 3) | 2)) + varint(UInt64(data.count)) + data
    }
    public static func text(_ field: Int, _ text: String) -> Data { blob(field, Data(text.utf8)) }
    static func readVarint(_ input: [UInt8], _ index: inout Int) throws -> UInt64? {
        let start = index
        var result: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard index < input.count else { index = start; return nil }
            let b = input[index]; index += 1
            if shift == 63 && b > 1 { throw WireError.malformed }
            result |= UInt64(b & 127) << shift
            if b & 128 == 0 { return result }
        }
        throw WireError.malformed
    }
}

/// TCP can split one message or coalesce several messages into any receive call.
public struct FrameBuffer {
    private var buffer = Data()
    public static let maxFrame = 1_048_576
    public init() {}
    public mutating func append(_ data: Data) throws -> [Data] {
        // A transport receive is capped at 64 KiB; bound incomplete frame storage.
        guard buffer.count + data.count <= Self.maxFrame + 65_546 else { throw WireError.oversized }
        buffer.append(data)
        let input = [UInt8](buffer)
        var offset = 0, messages: [Data] = []
        while offset < input.count {
            var cursor = offset
            guard let length = try Proto.readVarint(input, &cursor) else { break }
            guard length > 0, length <= UInt64(Self.maxFrame) else { throw WireError.oversized }
            guard input.count - cursor >= Int(length) else { break }
            let end = cursor + Int(length)
            messages.append(Data(input[cursor..<end]))
            offset = end
        }
        buffer = Data(input[offset...])
        return messages
    }
    public static func wrap(_ data: Data) -> Data { Proto.varint(UInt64(data.count)) + data }
}
