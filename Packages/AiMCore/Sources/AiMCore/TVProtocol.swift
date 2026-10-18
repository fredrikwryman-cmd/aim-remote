import Foundation

public enum TVKey: UInt64, CaseIterable {
    case home = 3, back = 4
    case zero = 7, one, two, three, four, five, six, seven, eight, nine
    case up = 19, down, left, right, ok
    case volumeUp = 24, volumeDown = 25, power = 26
    case enter = 66, delete = 67, menu = 82, search = 84
    case rewind = 89, fastForward = 90, mute = 164
    case play = 126, pause = 127
    case channelUp = 166, channelDown = 167, settings = 176
    case input = 178, guide = 172
}

public enum PairPhase: Equatable { case request, options, configuration, waitingCode, secret, complete }

public struct PairingExchange {
    public private(set) var phase: PairPhase = .request
    public init() {}
    public static func envelope(_ field: Int, _ body: Data) -> Data {
        Proto.uint(1, 2) + Proto.uint(2, 200) + Proto.blob(field, body)
    }
    public var request: Data {
        Self.envelope(10, Proto.text(1, "atvremote") + Proto.text(2, "AiM Remote"))
    }
    public mutating func receive(_ data: Data) throws -> Data? {
        let m = try Proto(data)
        guard m.number(2) == 200 else { throw WireError.unexpectedMessage }
        let encoding = Proto.uint(1, 3) + Proto.uint(2, 6)
        switch phase {
        case .request where m.bytes[11] != nil:
            phase = .options
            return Self.envelope(20, Proto.blob(1, encoding) + Proto.uint(3, 1))
        case .options where m.bytes[20] != nil:
            phase = .configuration
            return Self.envelope(30, Proto.blob(1, encoding) + Proto.uint(2, 1))
        case .configuration where m.bytes[31] != nil:
            phase = .waitingCode
            return nil
        case .secret where m.bytes[41] != nil:
            phase = .complete
            return nil
        default: throw WireError.unexpectedMessage
        }
    }
    public mutating func submit(digest: Data) throws -> Data {
        guard phase == .waitingCode, digest.count == 32 else { throw WireError.unexpectedMessage }
        phase = .secret
        return Self.envelope(40, Proto.blob(1, digest))
    }
}

public enum RemoteEvent {
    case started(Bool), textAvailable, voiceSession(UInt64), rejected
}

public struct RemoteExchange {
    // Ping, key, IME, voice, power and volume. No app/casting tab requested.
    public private(set) var features: UInt64 = 1 | 2 | 4 | 8 | 32 | 64
    public private(set) var imeCounter: UInt64 = 0
    public private(set) var fieldCounter: UInt64 = 0
    public private(set) var hasTextField = false
    public init() {}
    public mutating func receive(_ data: Data) throws -> (replies: [Data], events: [RemoteEvent]) {
        let m = try Proto(data)
        var replies: [Data] = [], events: [RemoteEvent] = []
        if let cfg = try m.child(1) {
            features &= cfg.number(1)
            guard features & 2 != 0 else { throw WireError.unexpectedMessage }
            let info = Proto.text(1, "iPhone") + Proto.text(2, "AiM") + Proto.uint(3, 1)
                + Proto.text(4, "1") + Proto.text(5, "aim.remote") + Proto.text(6, "0.1.0")
            replies.append(Proto.blob(1, Proto.uint(1, features) + Proto.blob(2, info)))
        }
        if m.bytes[2] != nil { replies.append(Proto.blob(2, Proto.uint(1, features))) }
        if let ping = try m.child(8) { replies.append(Proto.blob(9, Proto.uint(1, ping.number(1)))) }
        if let edit = try m.child(21) {
            imeCounter = edit.number(1); fieldCounter = edit.number(2)
            hasTextField = true; events.append(.textAvailable)
        }
        if let start = try m.child(40) { events.append(.started(start.number(1) != 0)) }
        if let voice = try m.child(30) { events.append(.voiceSession(voice.number(1))) }
        if m.bytes[3] != nil { events.append(.rejected) }
        return (replies, events)
    }
    public static func key(_ key: TVKey) -> Data {
        Proto.blob(10, Proto.uint(1, key.rawValue) + Proto.uint(2, 3))
    }
    /// Send into the currently focused TV text field. IME behaviour varies by TV app.
    public func text(_ text: String) throws -> Data {
        guard features & 4 != 0, hasTextField, !text.isEmpty, text.utf8.count <= 4096 else {
            throw WireError.unexpectedMessage
        }
        let end = UInt64(max(0, text.utf16.count - 1))
        let object = Proto.uint(1, end) + Proto.uint(2, end) + Proto.text(3, text)
        let edit = Proto.uint(1, 1) + Proto.blob(2, object)
        return Proto.blob(21, Proto.uint(1, imeCounter) + Proto.uint(2, fieldCounter) + Proto.blob(3, edit))
    }
    public static func voiceBegin(_ id: UInt64) -> Data { Proto.blob(30, Proto.uint(1, id)) }
    public static func voiceEnd(_ id: UInt64) -> Data { Proto.blob(32, Proto.uint(1, id)) }
    public static func voiceChunk(_ id: UInt64, _ pcm: Data) -> Data {
        Proto.blob(31, Proto.uint(1, id) + Proto.blob(2, pcm))
    }
}
