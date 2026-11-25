import XCTest
@testable import AiMCore

final class ProtocolTests: XCTestCase {
    func testKnownKeyBytes() throws {
        XCTAssertEqual(Array(RemoteExchange.key(.up)), [0x52, 4, 8, 19, 16, 3])
        XCTAssertEqual(Array(FrameBuffer.wrap(RemoteExchange.key(.up))), [6, 0x52, 4, 8, 19, 16, 3])
    }
    func testEveryPossibleTCPFragmentBoundary() throws {
        let one = Proto.text(90, String(repeating: "a", count: 200))
        let two = RemoteExchange.key(.ok)
        let combined = FrameBuffer.wrap(one) + FrameBuffer.wrap(two)
        for cut in 0...combined.count {
            var buffer = FrameBuffer()
            let a = try buffer.append(Data(combined.prefix(cut)))
            let b = try buffer.append(Data(combined.dropFirst(cut)))
            XCTAssertEqual(a + b, [one, two], "cut=\(cut)")
        }
    }
    func testOneByteAtATime() throws {
        let data = Proto.text(2, String(repeating: "Ö", count: 300))
        var buffer = FrameBuffer(), messages: [Data] = []
        for byte in FrameBuffer.wrap(data) { messages += try buffer.append(Data([byte])) }
        XCTAssertEqual(messages, [data])
    }
    func testMalformedAndOversizedMessages() throws {
        XCTAssertThrowsError(try Proto(Data([0])))
        XCTAssertThrowsError(try Proto(Data([0x12, 10, 1])))
        XCTAssertThrowsError(try Proto(Data([8] + Array(repeating: 255, count: 10))))
        var buffer = FrameBuffer()
        XCTAssertThrowsError(try buffer.append(Proto.varint(UInt64(FrameBuffer.maxFrame + 1))))
    }
    func testUnknownFieldsSkipped() throws {
        let data = Data([0x0d, 1, 2, 3, 4]) + Proto.text(2, "TV") + Data([0x19, 0, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(try Proto(data).string(2), "TV")
    }
    func testPairingStateMachine() throws {
        var pair = PairingExchange()
        XCTAssertEqual(try Proto(pair.request).child(10)?.string(2), "AiM Remote")
        let options = try XCTUnwrap(pair.receive(PairingExchange.envelope(11, Data())))
        XCTAssertEqual(try Proto(options).child(20)?.child(1)?.number(1), 3)
        _ = try pair.receive(PairingExchange.envelope(20, Data()))
        _ = try pair.receive(PairingExchange.envelope(31, Data()))
        XCTAssertEqual(pair.phase, .waitingCode)
        let secret = try pair.submit(digest: Data(repeating: 7, count: 32))
        XCTAssertEqual(try Proto(secret).child(40)?.bytes[1]?.first?.count, 32)
        _ = try pair.receive(PairingExchange.envelope(41, Proto.blob(1, Data(repeating: 7, count: 32))))
        XCTAssertEqual(pair.phase, .complete)
    }
    func testOutOfOrderAndRejectedPairing() throws {
        var pair = PairingExchange()
        XCTAssertThrowsError(try pair.submit(digest: Data(repeating: 0, count: 32)))
        XCTAssertThrowsError(try pair.receive(PairingExchange.envelope(41, Data())))
        XCTAssertThrowsError(try pair.receive(Proto.uint(2, 402)))
    }
    func testNegotiationAndPingInSameMessage() throws {
        var remote = RemoteExchange()
        let input = Proto.blob(1, Proto.uint(1, 103)) + Proto.blob(8, Proto.uint(1, 458))
        let result = try remote.receive(input)
        XCTAssertEqual(remote.features, 103)
        XCTAssertEqual(result.replies.count, 2)
        XCTAssertEqual(try Proto(result.replies[1]).child(9)?.number(1), 458)
    }
    func testHandshakeSendsTheAppVersionItWasGiven() throws {
        var remote = RemoteExchange(appVersion: "2.3.4")
        let result = try remote.receive(Proto.blob(1, Proto.uint(1, 103)))
        let negotiation = try XCTUnwrap(try Proto(result.replies[0]).child(1))
        let info = try XCTUnwrap(try negotiation.child(2))
        XCTAssertEqual(info.string(6), "2.3.4")
        // Fältordningen och de övriga fälten är oförändrade.
        XCTAssertEqual(info.string(1), "iPhone")
        XCTAssertEqual(info.string(2), "AiM")
        XCTAssertEqual(info.number(3), 1)
        XCTAssertEqual(info.string(4), "1")
        XCTAssertEqual(info.string(5), "aim.remote")
    }
    func testHandshakeFallsBackToAVersionWhenNoneIsGiven() throws {
        var remote = RemoteExchange()
        let result = try remote.receive(Proto.blob(1, Proto.uint(1, 103)))
        let info = try XCTUnwrap(try Proto(result.replies[0]).child(1)?.child(2))
        XCTAssertEqual(info.string(6), "1.0.0")
    }
    func testTextRequiresIMEAndKeepsCounters() throws {
        var remote = RemoteExchange()
        XCTAssertThrowsError(try remote.text("Hej"))
        _ = try remote.receive(Proto.blob(21, Proto.uint(1, 12) + Proto.uint(2, 34)))
        let sent = try Proto(remote.text("Å😀"))
        let batch = try XCTUnwrap(sent.child(21))
        XCTAssertEqual(batch.number(1), 12)
        XCTAssertEqual(batch.number(2), 34)
        XCTAssertEqual(try batch.child(3)?.child(2)?.string(3), "Å😀")
        XCTAssertEqual(try batch.child(3)?.child(2)?.number(1), 2)
    }
    func testVoicePacketHasCorrectSessionAndBytes() throws {
        let pcm = Data([0, 1, 2, 3])
        let packet = try Proto(RemoteExchange.voiceChunk(19, pcm)).child(31)
        XCTAssertEqual(packet?.number(1), 19)
        XCTAssertEqual(packet?.bytes[2]?.first, pcm)
    }
}
