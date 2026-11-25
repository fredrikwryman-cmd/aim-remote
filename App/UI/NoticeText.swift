import SwiftUI

// Felmeddelanden enligt mallen i punkt 6: vad hände · vad betyder det ·
// vad gör jag nu. Texterna i TVConnection är oförändrade: de är
// anslutningslogik, och översättningen till mallen görs här, i gränssnittet.
struct NoticeText {
    var what: String
    var means: String
    var next: String

    static func from(_ notice: String) -> NoticeText {
        let text = notice.lowercased()

        func has(_ needles: String...) -> Bool {
            needles.contains { text.contains($0.lowercased()) }
        }

        if has("kunde inte nås", "svarade inte i tid") {
            return NoticeText(
                what: "Hittar inte TV:n.",
                means: "Den kan vara avstängd eller på ett annat wifi.",
                next: "Starta TV:n och tryck Försök igen.")
        }
        if has("annat certifikat", "identitet har ändrats") {
            return NoticeText(
                what: "TV:n visar ett annat certifikat än det sparade.",
                means: "Det kan vara en annan TV, eller så har din TV återställts.",
                next: "Parkoppla igen om det är din TV.")
        }
        if has("välj din tv") {
            return NoticeText(
                what: "Ingen TV är vald.",
                means: "Appen vet inte vilken TV den ska styra.",
                next: "Välj TV i listan, eller skriv in TV:ns IP-adress.")
        }
        if has("tryck på parkoppla", "behöver parkopplas") {
            return NoticeText(
                what: "TV:n är inte parkopplad.",
                means: "Appen saknar TV:ns certifikat och får inte styra den.",
                next: "Tryck Parkoppla och skriv in de sex tecknen som visas på TV:n.")
        }
        if has("anslut till tv:n först") {
            return NoticeText(
                what: "Kommandot skickades inte.",
                means: "Appen är inte ansluten till TV:n.",
                next: "Tryck Anslut och försök igen.")
        }
        if has("stängdes", "stängde anslutningen") {
            return NoticeText(
                what: "Anslutningen bröts.",
                means: "TV:n eller nätverket avbröt den.",
                next: "Tryck Anslut och försök igen.")
        }
        if has("textfält") {
            return NoticeText(
                what: "Texten skickades inte.",
                means: "TV:n har inget skrivfält markerat, och alla TV-appar stöder inte textinmatning.",
                next: "Markera sökfältet på TV:n och skicka texten igen.")
        }
        if has("tillåt mikrofon") {
            return NoticeText(
                what: "Appen får inte använda mikrofonen.",
                means: "Röststyrningen behöver mikrofonen för att spela in.",
                next: "Tillåt mikrofon för Tech Rabbit Remote i iPhones inställningar.")
        }
        if has("röstinmatning", "röstsession") {
            return NoticeText(
                what: "Röststyrningen startade inte.",
                means: "TV:n öppnade ingen röstsession för den här anslutningen.",
                next: "Använd tangentbordet, eller försök igen.")
        }
        if has("senaste kommandot") {
            return NoticeText(
                what: "TV:n tog inte emot kommandot.",
                means: "Knappen stöds inte i det som visas på TV:n just nu.",
                next: "Prova en annan knapp, eller gör det direkt på TV:n.")
        }
        if has("kommandot kunde inte skickas") {
            return NoticeText(
                what: "Kommandot skickades inte.",
                means: "Anslutningen till TV:n bröts mitt i.",
                next: "Tryck Anslut och försök igen.")
        }
        // Okända fel: texten står kvar som den är, och mallens sista del
        // säger ändå vad man gör nu.
        return NoticeText(
            what: notice,
            means: "",
            next: "Starta TV:n, tryck Anslut och försök igen.")
    }

    /// Hela meddelandet på en rad, för VoiceOver.
    var spoken: String {
        [what, means, next].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
