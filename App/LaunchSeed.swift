import Foundation

/// UI-testerna startar appen med `-tr.remote.onboarded NO` och liknande. Sådana
/// värden hamnar i NSArgumentDomain, som ligger före appens egen domän vid
/// läsning. Skriver appen sedan ett nytt värde går det till den egna domänen
/// och läses aldrig tillbaka, så gränssnittet fastnar i startläget. Därför
/// flyttas värdena in i den egna domänen en gång vid start, varefter
/// argumentdomänen tas bort. Utan startargument görs ingenting.
enum LaunchSeed {
    private static let boolKeys = ["tr.remote.onboarded", "tr.remote.haptics"]
    private static let stringKeys = ["tr.remote.theme"]

    static func apply(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        var bools: [String: Bool] = [:]
        var strings: [String: String] = [:]
        for key in boolKeys where arguments.contains("-" + key) {
            bools[key] = defaults.bool(forKey: key)
        }
        for key in stringKeys where arguments.contains("-" + key) {
            if let value = defaults.string(forKey: key) { strings[key] = value }
        }
        guard !bools.isEmpty || !strings.isEmpty else { return }
        defaults.removeVolatileDomain(forName: UserDefaults.argumentDomain)
        for (key, value) in bools { defaults.set(value, forKey: key) }
        for (key, value) in strings { defaults.set(value, forKey: key) }
    }
}
