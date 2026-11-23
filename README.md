# Tech Rabbit Remote

En fristående fjärrkontroll för iPhone, byggd i SwiftUI, för TCL 43P635 med
Android TV 11. Arbetsnamn: **Tech Rabbit Remote**. Appen styr TV:n direkt över
det lokala nätverket med Android TV Remote Protocol v2 — ingen server, inget
konto och inget tredjepartsbibliotek.

Licens: [MIT](LICENSE). Referenser och tredjepartslicenser:
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Två huvudvyer enligt användarens referenser: **Fjärr** och **Inställningar**. Mörk bakgrund, mjukt rundade knappar och grön markering. Anslutning, sifferknappar, tangentbord och hjälp öppnas som underordnade paneler. Ingen Apps- eller Touchpad-flik, reklam eller prenumeration.

## Funktioner i koden

- TV-sökning med Bonjour och manuell IP-adress.
- Android TV Remote v2, kodparkoppling och sparad klientidentitet i iOS Keychain.
- TV-certifikatet binds till lyckad kodparkoppling och kontrolleras vid återanslutning.
- Pilknappar, OK, hem, tillbaka, volym, mute, kanal, guide, inställningar och medieknappar.
- Sifferpanel och textinmatning i TV:ns aktiva textfält.
- Röstinmatning med uttryckligt mikrofontillstånd, stoppknapp och 15-sekundersgräns.
- Anslutningsstatus, tidsgränser och återanslutning när appen öppnas igen.
- Knappvibration som kan stängas av.

Detta är en första testversion. Protokollimplementation och användargränssnitt är skrivna; funktion på den fysiska TV:n måste provas. Att en knapp kan skickas innebär inte att varje TV-app reagerar på den. Påslagning från standby beror på TV:ns nätverksläge. Text och röst kan variera mellan appar. Castsymbolen i referensen används här som TV-väljare; foto-/videocasting ingår inte.

## Bygga utan egen Mac

Projektet har en GitHub Actions-arbetsgång som kör på en macOS-maskin. Den:

1. kör protokolltesterna,
2. genererar Xcode-projektet från `project.yml`,
3. bygger och kör app- och skärmtester i en iPhone-simulator,
4. bygger en osignerad iPhone-app och paketerar `AiM-Remote-unsigned.ipa`.

Arbetsgången finns under **Actions → Build Tech Rabbit Remote for iPhone**. Den behöver ligga i ett GitHub-repository och kan startas med **Run workflow**. När den är grön finns IPA-filen i **Artifacts**. Ett källkodspaket eller en ZIP-fil är inte en installerad app.

## Installera från Windows när IPA-filen finns

Använd Sideloadly från https://sideloadly.io/ och följ verktygets aktuella Windows-anvisningar. Koppla iPhone till datorn, välj IPA-filen och signera med ditt eget Apple-konto i verktyget. Ange aldrig Apple-lösenord i chatten. Följ iPhones uppmaningar om utvecklarläge/tillit om de visas. Gratis Apple-signering gäller normalt sju dagar; installationen behöver då förnyas. Vi använder ingen betald Apple-prenumeration i detta projekt.

Efter installation: **Inställningar → TV och anslutning → välj TV → Parkoppla**. Mata in koden från TV:n. Din iPhone och TV är redan på samma wifi; nätverket ska inte konfigureras om.

## Lokal utveckling på en Mac

```sh
brew install xcodegen
xcodegen generate
swift test --package-path Packages/AiMCore
open AiMRemote.xcodeproj
```

iOS 16.4 eller senare. Swift 5.9 eller senare. Inga tredjepartsbibliotek länkas in i appen. Apple Network, Security, CryptoKit, AVFoundation och SwiftUI används.

## Validering och begränsningar

Windows kan kontrollera syntax och konfigurationsfiler men saknar Apples iOS-SDK. Endast ett lyckat Xcode-bygge kan verifiera Swift-typer, Apple-API:er och länkar. Testerna täcker bland annat fragmenterad TCP, flera meddelanden i samma läsning, felaktiga längder, parkopplingsordning, tangentkoder, IME-räknare, certifikat och två huvudvyer. De ersätter inte testning på din TCL.

Se `TESTA-PA-TV.md` för ett kort provningsprotokoll och `STATUS.md` för faktiskt genomförda kontroller.

## Privat data

Ingen server för användardata, inget analys-SDK och ingen reklam. Nätverkskommandon går till den valda TV:n. Klientens privata nyckel skapas på iPhone och lagras i Keychain. Mikrofonljud skickas bara under aktiv röstinmatning; TV:ns röstassistent kan i sin tur kontakta sin leverantör. Referensfotot med TV:ns serienummer ingår inte i appen eller detta källkodspaket.

## Protokollkällor

Implementation skriven för detta projekt utifrån Android TV Remote v2:s meddelandeformat. Protokollbeteende jämfört med https://github.com/tronikos/androidtvremote2 och https://github.com/odyshewroman/AndroidTVRemoteControl. Ingen kod eller demonyckel från Swift-biblioteket distribueras. Ursprunglig parningsspecifikation: https://android.googlesource.com/platform/external/google-tv-pairing-protocol/ .

Appen är fristående och inte utgiven av TCL, Google eller Apps Venture.

## Licens

Koden är utgiven under MIT-licensen, se [LICENSE](LICENSE). Referensprojekt och
deras licenstexter finns i
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
