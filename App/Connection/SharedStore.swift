import Foundation
import Security

/// Det som app och widget delar: App Group för aktiv TV och namn, och en
/// gemensam Keychain-grupp för klientidentiteten och listan över TV-apparater.
enum Shared {
    static let appGroup = "group.se.aim.remote"
    /// Gruppen skrivs utan teamprefix i entitlements. I koden behövs prefixet.
    static let keychainSuffix = "se.aim.remote.shared"
    /// Teamet som appen signeras med. Används bara om prefixet inte går att
    /// läsa ur en befintlig nyckelringspost.
    static let fallbackTeamPrefix = "99CF8F6HH4"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    /// Namnet som widgeten visar. Skrivs av appen, läses av widgeten.
    static var activeTVName: String? {
        get { defaults.string(forKey: "active.tv.name") }
        set { defaults.set(newValue, forKey: "active.tv.name") }
    }
    static var activeTVID: String? {
        get { defaults.string(forKey: "active.tv.id") }
        set { defaults.set(newValue, forKey: "active.tv.id") }
    }

    /// Teamprefixet, upptäckt i körtid. Faller tillbaka på det inskrivna.
    static let teamPrefix: String = discoveredTeamPrefix() ?? fallbackTeamPrefix

    /// Keychain-gruppen med teamprefix, upptäckt i körtid.
    static let keychainGroup: String = teamPrefix + "." + keychainSuffix

    /// Appens egen grupp, den som application-identifier ger. En fråga UTAN
    /// kSecAttrAccessGroup söker i alla grupper appen kommer åt, inte bara
    /// den egna, så gruppen måste namnges när något ska läsas eller raderas
    /// just där. nil betyder att den inte gick att avgöra, och då rörs
    /// ingenting.
    static let ownGroup: String? = {
        guard let bundle = Bundle.main.bundleIdentifier, !bundle.isEmpty else { return nil }
        return teamPrefix + "." + bundle
    }()

    /// Sant när appen faktiskt får använda den delade gruppen. I simulatorn
    /// och i testbygget saknas rättigheten, och då används appens egen grupp.
    static let sharedGroupAvailable: Bool = {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "aim.remote.shared-probe",
            kSecAttrAccount as String: "probe",
            kSecAttrAccessGroup as String: keychainGroup,
            kSecValueData as String: Data([1]),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(probe as CFDictionary, nil)
        var remove = probe
        remove[kSecValueData as String] = nil
        remove[kSecAttrAccessible as String] = nil
        if status == errSecSuccess || status == errSecDuplicateItem {
            SecItemDelete(remove as CFDictionary)
            return true
        }
        return false
    }()

    /// Lägger den delade gruppen på en nyckelringsfråga när den får användas.
    static func withGroup(_ query: [String: Any]) -> [String: Any] {
        guard sharedGroupAvailable else { return query }
        var copy = query
        copy[kSecAttrAccessGroup as String] = keychainGroup
        return copy
    }

    /// Lägger till en post utan grupp och läser tillbaka vilken grupp den
    /// hamnade i. Första delen av den strängen är teamprefixet.
    private static func discoveredTeamPrefix() -> String? {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "aim.remote.group-probe",
            kSecAttrAccount as String: "probe",
            kSecValueData as String: Data([0]),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecReturnAttributes as String: true
        ]
        var result: CFTypeRef?
        var status = SecItemAdd(probe as CFDictionary, &result)
        if status == errSecDuplicateItem {
            var read = probe
            read[kSecValueData as String] = nil
            read[kSecAttrAccessible as String] = nil
            status = SecItemCopyMatching(read as CFDictionary, &result)
        }
        defer {
            var remove = probe
            remove[kSecValueData as String] = nil
            remove[kSecAttrAccessible as String] = nil
            remove[kSecReturnAttributes as String] = nil
            SecItemDelete(remove as CFDictionary)
        }
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let group = attributes[kSecAttrAccessGroup as String] as? String,
              let prefix = group.split(separator: ".").first else { return nil }
        return String(prefix)
    }
}

/// En post som ska flyttas till den gemensamma gruppen.
enum SharedItem: String, CaseIterable {
    case clientKey
    case clientCertificate
    case tvList
}

/// Flytten av nyckelringsposter till den gemensamma gruppen. Originalet
/// raderas först när kopian är verifierad, och flytten går att köra om.
protocol KeychainMoving {
    /// Finns posten i gruppen? nil betyder appens egen grupp.
    func exists(_ item: SharedItem, group: String?) -> Bool
    /// Kopierar posten från appens grupp till den angivna.
    func copy(_ item: SharedItem, to group: String) throws
    func delete(_ item: SharedItem, group: String?) throws
}

struct KeychainMigrationReport: Equatable {
    var copied: [SharedItem] = []
    var removedOriginals: [SharedItem] = []
    var alreadyShared: [SharedItem] = []
    var missing: [SharedItem] = []
    var failed: [SharedItem] = []
}

enum KeychainMigrator {
    /// Kör flytten. Varje post: finns den redan delad raderas bara originalet.
    /// Annars kopieras den, kopian kontrolleras, och först då tas originalet
    /// bort. Misslyckas kopian lämnas originalet orört.
    @discardableResult
    static func run(items: [SharedItem] = SharedItem.allCases,
                    group: String,
                    using mover: KeychainMoving) -> KeychainMigrationReport {
        var report = KeychainMigrationReport()
        for item in items {
            let inShared = mover.exists(item, group: group)
            let inOwn = mover.exists(item, group: nil)

            if inShared {
                report.alreadyShared.append(item)
                if inOwn, (try? mover.delete(item, group: nil)) != nil {
                    report.removedOriginals.append(item)
                }
                continue
            }
            guard inOwn else {
                report.missing.append(item)
                continue
            }
            do {
                try mover.copy(item, to: group)
            } catch {
                report.failed.append(item)
                continue
            }
            // Originalet raderas bara när kopian verkligen finns.
            guard mover.exists(item, group: group) else {
                report.failed.append(item)
                continue
            }
            report.copied.append(item)
            if (try? mover.delete(item, group: nil)) != nil {
                report.removedOriginals.append(item)
            }
        }
        return report
    }
}

/// Riktig nyckelring. Nyckel och certifikat kopieras via sina exporterade
/// data, listan som vanlig post.
struct SystemKeychainMover: KeychainMoving {
    /// Appens egen grupp. nil betyder att den inte gick att avgöra; då
    /// rapporteras posten som saknad i stället för att sökas i alla grupper.
    private let ownGroup: String?

    init(ownGroup: String? = Shared.ownGroup) { self.ownGroup = ownGroup }

    /// En nyckelringsfråga utan kSecAttrAccessGroup gäller SAMTLIGA grupper
    /// appen kommer åt. Därför namnges gruppen alltid, och går den egna inte
    /// att namnge görs ingenting.
    private func resolved(_ group: String?) -> String? {
        group ?? ownGroup
    }

    func exists(_ item: SharedItem, group: String?) -> Bool {
        guard let scope = resolved(group) else { return false }
        var query = baseQuery(item)
        query[kSecReturnRef as String] = true
        query[kSecAttrAccessGroup as String] = scope
        var result: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
    }

    func copy(_ item: SharedItem, to group: String) throws {
        switch item {
        case .clientKey:
            var query = baseQuery(item)
            query[kSecReturnRef as String] = true
            if let ownGroup { query[kSecAttrAccessGroup as String] = ownGroup }
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let raw = result else { throw AppFailure.message("Nyckeln kunde inte läsas.") }
            let key = raw as! SecKey
            var error: Unmanaged<CFError>?
            guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
                throw AppFailure.message("Nyckeln kunde inte kopieras till den delade gruppen.")
            }
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrKeySizeInBits as String: 2048
            ]
            guard let imported = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
                throw AppFailure.message("Nyckeln kunde inte läsas tillbaka.")
            }
            var add = baseQuery(item)
            add[kSecValueRef as String] = imported
            add[kSecAttrAccessGroup as String] = group
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                throw AppFailure.message("Nyckeln kunde inte sparas i den delade gruppen (\(status)).")
            }

        case .clientCertificate:
            var query = baseQuery(item)
            query[kSecReturnRef as String] = true
            if let ownGroup { query[kSecAttrAccessGroup as String] = ownGroup }
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let raw = result else { throw AppFailure.message("Certifikatet kunde inte läsas.") }
            var add = baseQuery(item)
            add[kSecValueRef as String] = (raw as! SecCertificate)
            add[kSecAttrAccessGroup as String] = group
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                throw AppFailure.message("Certifikatet kunde inte sparas i den delade gruppen (\(status)).")
            }

        case .tvList:
            var query = baseQuery(item)
            query[kSecReturnData as String] = true
            if let ownGroup { query[kSecAttrAccessGroup as String] = ownGroup }
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { throw AppFailure.message("Listan kunde inte läsas.") }
            var add = baseQuery(item)
            add[kSecValueData as String] = data
            add[kSecAttrAccessGroup as String] = group
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                throw AppFailure.message("Listan kunde inte sparas i den delade gruppen (\(status)).")
            }
        }
    }

    func delete(_ item: SharedItem, group: String?) throws {
        // Utan grupp i frågan raderar SecItemDelete posten i alla grupper
        // appen kommer åt, alltså även den delade. Gruppen namnges därför
        // alltid, och kan den egna inte namnges raderas ingenting.
        guard let scope = resolved(group) else {
            throw AppFailure.message("Appens egen nyckelringsgrupp kunde inte avgöras.")
        }
        var query = baseQuery(item)
        query[kSecAttrAccessGroup as String] = scope
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppFailure.message("Posten kunde inte tas bort (\(status)).")
        }
    }

    private func baseQuery(_ item: SharedItem) -> [String: Any] {
        switch item {
        case .clientKey:
            return [kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: IdentityStore.tag,
                    kSecAttrKeyType as String: kSecAttrKeyTypeRSA]
        case .clientCertificate:
            return [kSecClass as String: kSecClassCertificate,
                    kSecAttrLabel as String: IdentityStore.certificateLabel]
        case .tvList:
            return [kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: KeychainTVStorage.service,
                    kSecAttrAccount as String: "tvs"]
        }
    }
}
