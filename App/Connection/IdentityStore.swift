import Foundation
import Security
import CryptoKit

enum AppFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

/// Minimal DER writer/reader for RSA certificates. No embedded private key.
enum DER {
    static func node(_ tag: UInt8, _ content: Data) -> Data {
        var count = content.count
        var length = Data()
        if count < 128 { length.append(UInt8(count)) }
        else {
            var octets: [UInt8] = []
            while count > 0 { octets.insert(UInt8(count & 255), at: 0); count >>= 8 }
            length.append(0x80 | UInt8(octets.count)); length.append(contentsOf: octets)
        }
        return Data([tag]) + length + content
    }
    static func seq(_ content: Data) -> Data { node(0x30, content) }
    static func integer(_ bytes: Data) -> Data {
        var n = Data(bytes.drop(while: { $0 == 0 }))
        if n.isEmpty { n = Data([0]) }
        if n.first! & 0x80 != 0 { n.insert(0, at: 0) }
        return node(2, n)
    }
    static func children(_ data: Data, expected: UInt8 = 0x30) throws -> [(UInt8, Data)] {
        let a = [UInt8](data)
        func read(_ i: inout Int) throws -> (UInt8, Data) {
            guard i + 2 <= a.count else { throw AppFailure.message("Ogiltigt certifikat.") }
            let tag = a[i]; i += 1
            var n = Int(a[i]); i += 1
            if n & 0x80 != 0 {
                let bytes = n & 0x7f
                guard bytes > 0, bytes <= 4, i + bytes <= a.count else {
                    throw AppFailure.message("Ogiltig certifikatlängd.")
                }
                n = 0
                for _ in 0..<bytes { n = (n << 8) | Int(a[i]); i += 1 }
            }
            guard n <= a.count - i else { throw AppFailure.message("Ofullständigt certifikat.") }
            let result = Data(a[i..<(i+n)]); i += n
            return (tag, result)
        }
        var i = 0
        let root = try read(&i)
        guard root.0 == expected, i == a.count else { throw AppFailure.message("Fel certifikatformat.") }
        // Parse the root content by wrapping each child through the same bounded reader.
        return try parseContent(root.1)
    }
    private static func parseContent(_ content: Data) throws -> [(UInt8, Data)] {
        let a = [UInt8](content)
        var i = 0, result: [(UInt8, Data)] = []
        while i < a.count {
            guard i + 2 <= a.count else { throw AppFailure.message("Ogiltig DER-data.") }
            let tag = a[i]; i += 1
            var n = Int(a[i]); i += 1
            if n & 128 != 0 {
                let bytes = n & 127
                guard bytes > 0, bytes <= 4, i + bytes <= a.count else { throw AppFailure.message("Ogiltig DER-längd.") }
                n = 0
                for _ in 0..<bytes { n = (n << 8) | Int(a[i]); i += 1 }
            }
            guard n <= a.count - i else { throw AppFailure.message("Ofullständig DER-data.") }
            result.append((tag, Data(a[i..<i+n]))); i += n
        }
        return result
    }
    static func rsaParts(_ key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let raw = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw AppFailure.message("Kunde inte läsa TV:ns publika nyckel.")
        }
        let children = try self.children(raw)
        guard children.count == 2, children.allSatisfy({ $0.0 == 2 }) else {
            throw AppFailure.message("TV:n använder inte det väntade RSA-formatet.")
        }
        return children.reduce(Data()) { $0 + Data($1.1.drop(while: { $0 == 0 })) }
    }
}

struct ClientIdentity {
    let identity: SecIdentity
    let publicKey: SecKey
}

enum IdentityStore {
    static let tag = Data("aim.remote.client.rsa.v1".utf8)
    static let certificateLabel = "AiM Remote client v1"

    /// Läser en post i den delade gruppen och, om den inte finns där, i alla
    /// grupper appen kommer åt. Det senare fångar en parkoppling som gjordes
    /// innan den delade gruppen fanns, så att en befintlig identitet aldrig
    /// förbigås och ersätts av en ny.
    private static func copyRef(_ query: [String: Any]) -> (OSStatus, CFTypeRef?) {
        var raw: CFTypeRef?
        var status = SecItemCopyMatching(Shared.withGroup(query) as CFDictionary, &raw)
        if status == errSecItemNotFound, Shared.sharedGroupAvailable {
            raw = nil
            status = SecItemCopyMatching(query as CFDictionary, &raw)
        }
        return (status, raw)
    }

    static func loadOrCreate() throws -> ClientIdentity {
        let (status, keyRaw) = copyRef([
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ])
        var raw: CFTypeRef? = keyRaw
        let key: SecKey
        if status == errSecSuccess, let raw {
            key = (raw as! SecKey)
        } else if status == errSecItemNotFound {
            var privateAttributes: [String: Any] = [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            if Shared.sharedGroupAvailable {
                // Nya nycklar skapas direkt i den delade gruppen.
                privateAttributes[kSecAttrAccessGroup as String] = Shared.keychainGroup
            }
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeySizeInBits as String: 2048,
                kSecPrivateKeyAttrs as String: privateAttributes
            ]
            var error: Unmanaged<CFError>?
            guard let created = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                throw AppFailure.message("Kunde inte skapa appens säkra nyckel.")
            }
            key = created
        } else { throw AppFailure.message("Nyckelringen kunde inte öppnas (\(status)).") }
        guard let publicKey = SecKeyCopyPublicKey(key) else { throw AppFailure.message("Publik nyckel saknas.") }

        let (certStatus, certRaw) = copyRef([
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel,
            kSecReturnRef as String: true
        ])
        raw = certRaw
        let cert: SecCertificate
        if certStatus == errSecSuccess, let raw { cert = raw as! SecCertificate }
        else if certStatus == errSecItemNotFound {
            let data = try makeCertificate(key, publicKey)
            guard let created = SecCertificateCreateWithData(nil, data as CFData) else {
                throw AppFailure.message("Kunde inte skapa klientcertifikatet.")
            }
            let add: [String: Any] = Shared.withGroup([
                kSecClass as String: kSecClassCertificate,
                kSecValueRef as String: created,
                kSecAttrLabel as String: certificateLabel,
                // Samma skyddsklass som nyckeln: läsbar efter första
                // upplåsningen, aldrig synkad och aldrig utanför enheten.
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ])
            guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
                throw AppFailure.message("Kunde inte spara klientcertifikatet.")
            }
            cert = created
        } else { throw AppFailure.message("Klientcertifikatet kunde inte läsas.") }

        let (identityStatus, identityRaw) = copyRef([
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ])
        guard identityStatus == errSecSuccess,
              let identities = identityRaw as? [SecIdentity] else {
            throw AppFailure.message("Klientidentiteten saknas.")
        }
        let expected = SecCertificateCopyData(cert) as Data
        for identity in identities {
            var candidate: SecCertificate?
            if SecIdentityCopyCertificate(identity, &candidate) == errSecSuccess,
               let candidate, SecCertificateCopyData(candidate) as Data == expected {
                return ClientIdentity(identity: identity, publicKey: publicKey)
            }
        }
        throw AppFailure.message("Certifikatet matchar inte appens nyckel.")
    }

    private static func makeCertificate(_ privateKey: SecKey, _ publicKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let publicDER = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw AppFailure.message("Kunde inte skapa certifikatets publika nyckel.")
        }
        let sha256RSA = DER.seq(DER.node(6, Data([0x2a,0x86,0x48,0x86,0xf7,0x0d,1,1,11])) + DER.node(5, Data()))
        let rsa = DER.seq(DER.node(6, Data([0x2a,0x86,0x48,0x86,0xf7,0x0d,1,1,1])) + DER.node(5, Data()))
        let name = DER.seq(DER.node(0x31, DER.seq(DER.node(6, Data([0x55,4,3])) + DER.node(12, Data("AiM Remote".utf8)))))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        let now = Date()
        let dates = DER.seq(DER.node(0x18, Data(formatter.string(from: now.addingTimeInterval(-86400)).utf8))
                         + DER.node(0x18, Data(formatter.string(from: now.addingTimeInterval(10*365*86400)).utf8)))
        var serial = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, serial.count, &serial) == errSecSuccess else {
            throw AppFailure.message("Kunde inte skapa certifikatets serienummer.")
        }
        let tbs = DER.seq(DER.node(0xa0, DER.integer(Data([2]))) + DER.integer(Data(serial))
            + sha256RSA + name + dates + name + DER.seq(rsa + DER.node(3, Data([0]) + publicDER)))
        guard let signature = SecKeyCreateSignature(privateKey, .rsaSignatureMessagePKCS1v15SHA256,
                                                   tbs as CFData, &error) as Data? else {
            throw AppFailure.message("Kunde inte signera klientcertifikatet.")
        }
        return DER.seq(tbs + sha256RSA + DER.node(3, Data([0]) + signature))
    }

    static func pairingDigest(code: String, clientKey: SecKey, serverKey: SecKey) throws -> Data {
        let s = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let chars = Array(s.utf8)
        guard chars.count == 6, chars.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) }) else {
            throw AppFailure.message("Ange TV:ns sex tecken: siffrorna 0–9 och bokstäverna A–F.")
        }
        let a = UInt8(s.prefix(2), radix: 16)!
        let b = UInt8(s.dropFirst(2).prefix(2), radix: 16)!
        let c = UInt8(s.suffix(2), radix: 16)!
        let data = try DER.rsaParts(clientKey) + DER.rsaParts(serverKey) + Data([b,c])
        let digest = Data(SHA256.hash(data: data))
        guard digest.first == a else { throw AppFailure.message("Koden stämmer inte. Kontrollera koden på TV:n.") }
        return digest
    }
}

/// Peer certificates are pinned only after successful, code-authenticated pairing.
enum TrustStore {
    static func read(host: String) throws -> Data? {
        var result: CFTypeRef?
        var query = base(host)
        query[kSecReturnData as String] = true
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw AppFailure.message("Kunde inte läsa sparad parkoppling.") }
        return result as? Data
    }
    static func write(host: String, data: Data) throws {
        let status = SecItemUpdate(base(host) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw AppFailure.message("Kunde inte uppdatera parkopplingen.") }
        var query = base(host)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw AppFailure.message("Kunde inte spara parkopplingen.")
        }
    }
    static func forget(host: String) { SecItemDelete(base(host) as CFDictionary) }
    private static func base(_ host: String) -> [String: Any] {
        Shared.withGroup([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "aim.remote.tv-trust.v1",
            kSecAttrAccount as String: host.lowercased()
        ])
    }
}
