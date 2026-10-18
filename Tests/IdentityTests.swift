import XCTest
import Security
import CryptoKit
@testable import AiMRemote

final class IdentityTests: XCTestCase {
    func testGeneratedIdentityIsPersistentAndSelfSigned() throws {
        let first = try IdentityStore.loadOrCreate()
        let second = try IdentityStore.loadOrCreate()
        var a: SecCertificate?, b: SecCertificate?
        XCTAssertEqual(SecIdentityCopyCertificate(first.identity, &a), errSecSuccess)
        XCTAssertEqual(SecIdentityCopyCertificate(second.identity, &b), errSecSuccess)
        let cert = try XCTUnwrap(a), cert2 = try XCTUnwrap(b)
        let bytes = SecCertificateCopyData(cert) as Data
        XCTAssertEqual(bytes, SecCertificateCopyData(cert2) as Data)
        let parts = try DER.children(bytes)
        XCTAssertEqual(parts.count, 3)
        let tbs = DER.seq(parts[0].1)
        let signature = Data(parts[2].1.dropFirst())
        var error: Unmanaged<CFError>?
        XCTAssertTrue(SecKeyVerifySignature(first.publicKey, .rsaSignatureMessagePKCS1v15SHA256,
                                           tbs as CFData, signature as CFData, &error))
    }
    func testRSAExtractionAndPairingDigest() throws {
        let identity = try IdentityStore.loadOrCreate()
        let parts = try DER.rsaParts(identity.publicKey)
        XCTAssertEqual(parts.count, 259) // 256-byte modulus + 010001 exponent
        let digest = Data(SHA256.hash(data: parts + parts + Data([0xab, 0xcd])))
        let code = String(format: "%02XABCD", digest.first!)
        XCTAssertEqual(try IdentityStore.pairingDigest(code: code, clientKey: identity.publicKey,
                                                     serverKey: identity.publicKey), digest)
        XCTAssertThrowsError(try IdentityStore.pairingDigest(code: "ZZ0000", clientKey: identity.publicKey,
                                                           serverKey: identity.publicKey))
        let wrong = String(format: "%02XABCD", digest.first! ^ 1)
        XCTAssertThrowsError(try IdentityStore.pairingDigest(code: wrong, clientKey: identity.publicKey,
                                                           serverKey: identity.publicKey))
    }
    func testTrustIsScopedToHost() throws {
        let host = "unit-test-\(UUID().uuidString).local"
        defer { TrustStore.forget(host: host) }
        XCTAssertNil(try TrustStore.read(host: host))
        let fingerprint = Data(repeating: 123, count: 32)
        try TrustStore.write(host: host, data: fingerprint)
        XCTAssertEqual(try TrustStore.read(host: host), fingerprint)
        XCTAssertNil(try TrustStore.read(host: host + "-other"))
    }
}
