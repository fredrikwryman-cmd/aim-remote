import Foundation

/// Versionen appen visar läses ur bundlen, så siffran i Inställningar och
/// hjälptexten alltid är densamma som `MARKETING_VERSION` i project.yml och
/// den som står i App Store. Ingen version skrivs in för hand i gränssnittet.
enum AppVersion {

    /// `CFBundleShortVersionString`, satt till `$(MARKETING_VERSION)` i
    /// Info.plist. Nyckeln finns alltid i ett byggt paket; reservvärdet är
    /// bara till för att en tom sträng aldrig ska nå skärmen.
    static var marketing: String {
        guard let value = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !value.isEmpty else { return "1.0.0" }
        return value
    }

    /// Raden längst ner i Inställningar, till exempel "Version 1.0.0".
    static var label: String { "Version \(marketing)" }
}
