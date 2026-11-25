import Foundation
import Security
import CryptoKit

/// En rad i anslutningsloggen. Bara sådant som går att visa: inga nycklar och
/// inga hela certifikat, utan korta avtryck som räcker för att se om det är
/// samma identitet och samma TV som förra gången.
struct ConnectionLogEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var tvName: String
    var host: String
    /// De åtta första tecknen av SHA-256 över appens klientcertifikat.
    var identity: String
    /// Pinnat fingeravtryck, förkortat.
    var expected: String
    /// Fingeravtrycket TV:n visade, förkortat.
    var presented: String
    var result: String
    var reason: String

    init(id: UUID = UUID(), date: Date = Date(), tvName: String, host: String,
         identity: String, expected: String, presented: String,
         result: String, reason: String) {
        self.id = id
        self.date = date
        self.tvName = tvName
        self.host = host
        self.identity = identity
        self.expected = expected
        self.presented = presented
        self.result = result
        self.reason = reason
    }

    /// Egen formaterare per anrop: en delad DateFormatter är inte trådsäker.
    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// En rad text, avsedd att läsas i panelen och att klistras in.
    var line: String {
        var text = "\(Self.stamp(date))  \(result)"
        text += "\n  TV: \(tvName.isEmpty ? "-" : tvName) · \(host.isEmpty ? "-" : host)"
        text += "\n  Identitet: \(identity) · förväntat: \(expected) · TV visade: \(presented)"
        if !reason.isEmpty { text += "\n  \(reason)" }
        return text
    }
}

/// Ringbuffert med de senaste försöken. Sparas i App Group-domänen, så den
/// överlever omstart av appen och av telefonen.
@MainActor
final class ConnectionLog {
    static let shared = ConnectionLog()

    static let limit = 50
    private static let key = "connection.log.v1"

    private let defaults: UserDefaults
    private(set) var entries: [ConnectionLogEntry]

    init(defaults: UserDefaults = Shared.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([ConnectionLogEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    /// Lägger till en rad och kastar den äldsta när bufferten är full.
    func record(_ entry: ConnectionLogEntry) {
        entries.append(entry)
        if entries.count > Self.limit {
            entries.removeFirst(entries.count - Self.limit)
        }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    /// Nyast först, som panelen visar den och som den kopieras.
    var text: String {
        guard !entries.isEmpty else { return "Anslutningsloggen är tom." }
        let head = "Tech Rabbit Remote · anslutningslogg · senaste \(Self.limit) försöken"
        return ([head] + entries.reversed().map(\.line)).joined(separator: "\n\n")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.key)
    }

    // MARK: - Korta avtryck

    /// De första åtta tecknen av ett SHA-256 i hex.
    static func short(_ digest: Data?, length: Int = 16) -> String {
        guard let digest, !digest.isEmpty else { return "-" }
        return digest.map { String(format: "%02x", $0) }.joined().prefix(length).lowercased()
    }

    /// Klientidentiteten, igenkännbar men inte återskapbar: SHA-256 över
    /// certifikatet, åtta tecken. Själva certifikatet loggas aldrig.
    static func identityLabel(_ identity: SecIdentity?) -> String {
        guard let identity else { return "-" }
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              let certificate else { return "-" }
        let digest = Data(SHA256.hash(data: SecCertificateCopyData(certificate) as Data))
        return short(digest, length: 8)
    }
}
