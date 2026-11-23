import Foundation
import Security

/// En sparad TV. Identiteten är certifikatets fingeravtryck, inte adressen.
struct SavedTV: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var host: String
    /// SHA-256 av TV:ns certifikat i DER-form.
    var fingerprint: Data
    var lastConnected: Date?

    init(id: String = UUID().uuidString, name: String, host: String,
         fingerprint: Data, lastConnected: Date? = nil) {
        self.id = id
        self.name = name
        self.host = host.lowercased()
        self.fingerprint = fingerprint
        self.lastConnected = lastConnected
    }
}

/// Var listan ligger. Keychain i appen, minne i testerna.
protocol SavedTVStorage: AnyObject {
    func read() -> Data?
    func write(_ data: Data) throws
}

/// Samma skydd som klientnyckeln och den gamla pinningen:
/// generic password, AfterFirstUnlockThisDeviceOnly.
final class KeychainTVStorage: SavedTVStorage {
    static let service = "aim.remote.tv-list.v1"
    private let account: String

    init(account: String = "tvs") { self.account = account }

    private var base: [String: Any] {
        Shared.withGroup([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ])
    }

    func read() -> Data? {
        var query = base
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func write(_ data: Data) throws {
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else {
            throw AppFailure.message("Kunde inte uppdatera listan över TV-apparater.")
        }
        var query = base
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw AppFailure.message("Kunde inte spara listan över TV-apparater.")
        }
    }
}

final class MemoryTVStorage: SavedTVStorage {
    private var data: Data?
    init(_ data: Data? = nil) { self.data = data }
    func read() -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
}

/// Listan med sparade TV-apparater och vilken som är aktiv.
final class SavedTVStore {
    private struct Payload: Codable {
        var tvs: [SavedTV] = []
        var activeID: String?
    }

    private let storage: SavedTVStorage
    private var payload: Payload

    init(storage: SavedTVStorage = KeychainTVStorage()) {
        self.storage = storage
        if let data = storage.read(), let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            payload = decoded
        } else {
            payload = Payload()
        }
    }

    var all: [SavedTV] { payload.tvs }
    var activeID: String? { payload.activeID }
    var active: SavedTV? { payload.tvs.first { $0.id == payload.activeID } }

    func tv(id: String) -> SavedTV? { payload.tvs.first { $0.id == id } }
    func tv(fingerprint: Data) -> SavedTV? { payload.tvs.first { $0.fingerprint == fingerprint } }
    func tv(host: String) -> SavedTV? {
        let clean = host.lowercased()
        return payload.tvs.first { $0.host == clean }
    }

    func setActive(_ id: String?) {
        payload.activeID = id
        save()
    }

    /// Lägger till eller uppdaterar posten för ett fingeravtryck. Samma TV på ny
    /// adress uppdaterar bara host, aldrig fingeravtrycket.
    @discardableResult
    func upsert(name: String, host: String, fingerprint: Data, makeActive: Bool = true) -> SavedTV {
        let clean = host.lowercased()
        var saved: SavedTV
        if let index = payload.tvs.firstIndex(where: { $0.fingerprint == fingerprint }) {
            payload.tvs[index].host = clean
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload.tvs[index].name = name
            }
            payload.tvs[index].lastConnected = Date()
            saved = payload.tvs[index]
        } else {
            saved = SavedTV(name: name, host: clean, fingerprint: fingerprint, lastConnected: Date())
            payload.tvs.append(saved)
        }
        if makeActive { payload.activeID = saved.id }
        save()
        return saved
    }

    func touch(id: String) {
        guard let index = payload.tvs.firstIndex(where: { $0.id == id }) else { return }
        payload.tvs[index].lastConnected = Date()
        save()
    }

    func rename(id: String, to name: String) {
        guard let index = payload.tvs.firstIndex(where: { $0.id == id }) else { return }
        payload.tvs[index].name = name
        save()
    }

    /// Tar bort en TV och dess pinning. Var den aktiv blir ingen TV aktiv.
    func forget(id: String, alsoClearTrustStore: Bool = true) {
        guard let index = payload.tvs.firstIndex(where: { $0.id == id }) else { return }
        let removed = payload.tvs.remove(at: index)
        if payload.activeID == removed.id { payload.activeID = nil }
        save()
        if alsoClearTrustStore { TrustStore.forget(host: removed.host) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? storage.write(data)
    }

    // MARK: - Migrering

    /// Flyttar in den TV som sparades före listan: host och namn ur
    /// UserDefaults och det pinnade fingeravtrycket ur TrustStore. Körs en gång
    /// och går att köra om: finns fingeravtrycket redan händer ingenting.
    @discardableResult
    func migrateLegacy(host: String?, name: String?, fingerprint: Data?) -> SavedTV? {
        guard let host, !host.isEmpty, let fingerprint, !fingerprint.isEmpty else { return nil }
        if let existing = tv(fingerprint: fingerprint) {
            if payload.activeID == nil { setActive(existing.id) }
            return existing
        }
        let saved = SavedTV(
            name: (name?.isEmpty == false ? name! : "TV"),
            host: host,
            fingerprint: fingerprint,
            lastConnected: nil
        )
        payload.tvs.append(saved)
        if payload.activeID == nil { payload.activeID = saved.id }
        save()
        return saved
    }
}

/// Beslutet när ett TV-certifikat dyker upp under handskakningen.
/// Ren logik, utan nätverk, så att den går att testa.
enum TVTrust {
    enum Decision: Equatable {
        /// Känd TV. hostChanged betyder att samma certifikat nu svarar på en ny adress.
        case accept(id: String, hostChanged: Bool)
        /// Parkoppling pågår: certifikatet godtas och sparas när koden stämmer.
        case pairing
        /// Känd adress men ett annat certifikat. Anslutningen stoppas.
        case mismatch(name: String)
        /// Okänd TV utan parkoppling.
        case unknown
    }

    static func decide(saved: [SavedTV], host: String, fingerprint: Data, pairing: Bool) -> Decision {
        if pairing { return .pairing }
        let clean = host.lowercased()
        if let match = saved.first(where: { $0.fingerprint == fingerprint }) {
            // Samma TV: adressen kan ha ändrats sedan sist.
            return .accept(id: match.id, hostChanged: match.host != clean)
        }
        if let onHost = saved.first(where: { $0.host == clean }) {
            // Känd adress men nytt certifikat: aldrig tyst byte.
            return .mismatch(name: onHost.name)
        }
        return .unknown
    }
}
