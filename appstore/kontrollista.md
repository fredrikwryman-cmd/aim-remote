# Kontrollista inför App Store-granskning · Remote

Status per rad: **KLART** (ligger i repot och behöver inget mer), **FREDRIK
GÖR** (kräver App Store Connect, Apple-kontot eller ett beslut du äger),
**SAKNAS** (behövs och finns inte än).

Allt du själv ska göra står samlat som numrerade steg längst ned.

---

## Adresser

| Vad | Adress | Status |
|---|---|---|
| Support-URL | https://fredrikwryman-cmd.github.io/aim-remote/site/support.html | KLART, svarar 200 |
| URL till integritetspolicy | https://fredrikwryman-cmd.github.io/aim-remote/site/integritet.html | KLART, svarar 200 |
| Startsida för sidorna | https://fredrikwryman-cmd.github.io/aim-remote/ | KLART, svarar 200 |

GitHub Pages är påslaget för repot med källa `main` och mappen `/docs`, och
bygget gick igenom. Sidorna ligger i `docs/site/`, så ändrar du dem räcker det
att pusha; Pages bygger om av sig självt inom en minut eller två.

Supportmejlen är **SAKNAS** på båda sidorna, markerad med
`[SAKNAS: supportmejl]` i texten. Apple kräver ett sätt att nå dig, och vilken
adress som ska stå offentligt på webben är ditt beslut, inte något jag ska
gissa. Se steg 1 nedan.

---

## Appen och bygget

| Punkt | Läge | Status |
|---|---|---|
| Bundle-ID | `se.aim.remote`, widgeten `se.aim.remote.widget` | KLART |
| Appnamn i bundlen | `Tech Rabbit Remote` (`CFBundleDisplayName`) | KLART |
| Appikon 1024 | `App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, 1024 × 1024, PNG färgtyp 2 (RGB), ingen alfakanal, ingen `tRNS`-chunk | KLART |
| Version (`MARKETING_VERSION`) | `0.1.0` | FREDRIK GÖR, se steg 2 |
| Buildnummer (`CURRENT_PROJECT_VERSION`) | `1` | FREDRIK GÖR, se steg 2 |
| Lägsta iOS | 16.4 för appen, 17.0 för widgeten | KLART |
| Enheter | Bara iPhone (`TARGETED_DEVICE_FAMILY = 1`), bara porträtt | KLART |
| Integritetsmanifest | `App/PrivacyInfo.xcprivacy` och `Widget/PrivacyInfo.xcprivacy` | KLART |
| Export och kryptering | `ITSAppUsesNonExemptEncryption = false` i `App/Info.plist` | KLART |
| Rättigheter | App group `group.se.aim.remote`, nyckelringsgrupp `se.aim.remote.shared`, båda på appen och widgeten | KLART i koden, FREDRIK GÖR i portalen, se steg 3 |
| Bygget är grönt | `ios.yml` kör protokolltester, app- och UI-tester och ett osignerat iPhone-bygge | KLART |

### Kryptering och export, varför `false`

`ITSAppUsesNonExemptEncryption` står på `false`, och det är rätt svar här.
Nyckeln betyder inte "appen krypterar inget", utan "appen använder ingen
**icke-undantagen** kryptering". Allt appen gör ligger inom Apples undantag:

- TLS sätts upp med `NWProtocolTLS` ur Apples Network-ramverk. Det är
  kryptering som operativsystemet tillhandahåller, och den är undantagen.
- Klientnyckeln är en RSA-nyckel i iOS nyckelring, och signeringen görs med
  `SecKeyCreateSignature` ur Apples Security-ramverk. Nycklar och signaturer
  används bara för att TV:n ska känna igen telefonen, alltså autentisering,
  som har ett eget undantag.
- `SHA256` ur Apples CryptoKit används till att jämföra avtrycket av TV:ns
  certifikat. En hashfunktion är inte kryptering.
- Ingen egen krypteringskod och inget tredjepartsbibliotek finns i appen.

Med nyckeln satt till `false` i Info.plist hoppar App Store Connect över
exportfrågan vid varje uppladdning, i stället för att fråga om samma sak varje
gång. Ingen årlig självklassificering (ERN eller CCATS) behövs för den här
appen.

---

## Text och bilder i butiken

| Punkt | Läge | Status |
|---|---|---|
| Namn, undertitel, reklamtext, beskrivning, sökord, kategori, åldersgräns, copyright | Färdigt i `appstore/butikstext.md` med teckenantal per fält | KLART att klistra in, FREDRIK GÖR i App Store Connect |
| App Privacy | Svaren står i `appstore/integritet.md`. Väntat svar: Data Not Collected | FREDRIK GÖR, se steg 5 |
| Skärmbilder | `appstore/skarmbilder/1206x2622/` (6,3 tum, krävs) och `appstore/skarmbilder/1320x2868/` (6,9 tum, frivilligt). Tio bilder per storlek: Fjärr, Välj TV, Sifferknappar, Tangentbord och Inställningar, först mörkt och sedan ljust | KLART |
| Appförhandsvisning (video) | Finns inte, och Apple kräver den inte | Behövs inte |

**En sak att titta på innan du laddar upp.** Appen visar `TCL 43P635` som
TV-namn innan någon TV är vald, och det syns i bild 01 och 06. Beskrivningen
säger att appen inte kommer från TCL, så i värsta fall läser en granskare
modellnamnet i bilden som att appen utger sig för att vara TCL:s. Risken är
liten men den finns. Vill du bort från den, byt standardnamnet i
`App/Connection/TVConnection.swift` till något neutralt, till exempel
`Min TV`, och kör skärmbildsflödet igen. Det ändrar appens utseende, och
därför har jag inte gjort det på eget bevåg.

Bilderna är raka skärmbilder utan ramar och utan pålagd text, tagna av
`.github/workflows/butiksbilder.yml`. Vill du ta om dem efter en ändring i
appen: **Actions → App Store screenshots → Run workflow**, och hämta
artifacten `TechRabbitRemote-appstore-<storlek>`.

**Storlekarna.** App Store Connect kräver i dag ett set för iPhone:
6,3-tumsklassen, som i gränssnittet heter *iPhone with Dynamic Island (medium
display)* och tar 1206 × 2622 eller 1179 × 2556 pixlar. 6,9 tum (1320 × 2868)
blev frivilligt i oktober 2026 och skalas annars från det du laddar upp. Båda
storlekarna är tagna här, så stora skärmar får bilder i rätt mått i stället
för skalade. Tio bilder är också precis så många Apple tar emot per storlek.

---

## Tillstånd och texter i appen

| Punkt | Text | Status |
|---|---|---|
| `NSLocalNetworkUsageDescription` | "Tech Rabbit Remote använder ditt lokala nätverk för att hitta och styra din TV." | KLART |
| `NSMicrophoneUsageDescription` | "Tech Rabbit Remote skickar din röst till TV:n när du startar mikrofonen." | KLART |
| `NSBonjourServices` | `_androidtvremote2._tcp` | KLART |

Båda texterna står på samma plats i appen och i widgeten, och säger vad
tillståndet används till i stället för att bara upprepa att det behövs. Det är
vad Apple vill se, och granskare fäller regelbundet appar som skriver
"appen behöver åtkomst till ditt lokala nätverk" och inget mer. Bonjour-listan
innehåller bara den tjänst appen faktiskt letar efter; en bredare lista eller
en lista som inte matchar koden är en vanlig anmärkning.

---

## Granskningsanteckning till Apple

Klistra in det här i **App Review Information → Notes**. Texten är på engelska
eftersom granskarna läser engelska.

```
This app is a remote control for Google TV / Android TV televisions. It talks
directly to the TV over the local network using the Android TV Remote
Protocol v2. There is no server, no account and no login, so there are no
demo credentials to provide.

To use the app with a television, the iPhone and the TV must be on the same
Wi-Fi network. We understand a Google TV may not be available in the review
environment. The app is still fully reviewable without one:

1. Launch the app. The start screen and the remote screen are shown without
   any TV present.
2. Tap Settings, then "TV och anslutning", then "Välj TV". The app asks for
   local network permission and starts searching. With no TV on the network it
   shows the empty state: "Ingen TV hittades."
3. Back in "TV och anslutning", the section "MANUELL ADRESS" accepts any IP
   address or host name. Entering one and tapping "Parkoppla med kod på TV:n"
   starts the pairing flow, so the pairing screen and its code entry can be
   inspected without a television. Pairing itself will of course time out
   without a TV answering.
4. All other screens (number pad, keyboard input, help, settings) are reachable
   and fully functional without a connection.

Microphone: the app requests microphone access only for voice search. Audio is
streamed to the user's own television during an active voice session and is
never sent to us or to any third party. There is no analytics, no advertising
and no third-party SDK in the app.

The app is independent. It is not published by, endorsed by or affiliated with
TCL or Google. Android TV and Google TV are trademarks of Google.

Contact: Fredrik Ryman, TechRabbit — <fyll i supportmejlen>
```

Demo-video behövs inte. Granskaren kommer åt varje skärm utan TV, och det är
vad anteckningen beskriver. Faller inlämningen på 2.1 Performance ändå, spela
en skärminspelning på din egen telefon mot din TCL och lägg den under App
Review Information som bilaga; då slipper du en ny anmärkning i nästa runda.

---

## Kontaktuppgifter

| Fält i App Store Connect | Värde | Status |
|---|---|---|
| App Review Information: förnamn, efternamn | Fredrik Ryman | FREDRIK GÖR |
| App Review Information: telefon | Ditt nummer | FREDRIK GÖR |
| App Review Information: e-post | Samma adress som på supportsidan | FREDRIK GÖR |
| Utvecklarnamn som visas i butiken | TechRabbit | FREDRIK GÖR, sätts på kontot |

Kontaktuppgifterna under App Review Information visas inte offentligt. Det är
bara supportsidans adress som är publik.

---

## Det du själv ska göra

1. **Bestäm supportmejlen.** Välj en adress som får stå på en öppen webbsida.
   Byt ut `[SAKNAS: supportmejl]` i `docs/site/support.html` och
   `docs/site/integritet.html`, och `<fyll i supportmejlen>` i
   granskningsanteckningen ovan. Pusha, och Pages bygger om sidorna själv.

2. **Sätt version och buildnummer.** `project.yml` har `MARKETING_VERSION:
   '0.1.0'` och `CURRENT_PROJECT_VERSION: '1'`. En första version i butiken
   ska normalt vara `1.0.0`. Ändra raderna i `project.yml`, inte i Xcode, för
   projektet genereras om vid varje bygge. Buildnummret måste höjas för varje
   uppladdning till samma version; `1` är ledigt så länge inget laddats upp.

3. **Lägg upp identifierarna i Apple Developer.** Appens ID `se.aim.remote`
   och widgetens `se.aim.remote.widget`, app group `group.se.aim.remote` och
   nyckelringsgruppen `se.aim.remote.shared`. Både appen och widgeten ska ha
   app group och nyckelringsgrupp påslagna, annars kan widgeten inte läsa
   TV-listan.

4. **Skapa appen i App Store Connect** med bundle-ID `se.aim.remote`, svenska
   som primärt språk och namnet ur `appstore/butikstext.md`. Säger App Store
   Connect att namnet är taget, ta andrahandsnamnet i samma fil.

5. **Fyll i App Privacy** enligt `appstore/integritet.md`. Svaret är *No, we do
   not collect data from this app*. Publicera avsnittet.

6. **Klistra in butikstexten** ur `appstore/butikstext.md`: namn, undertitel,
   reklamtext, beskrivning, sökord, kategori, copyright, support-URL och URL
   till integritetspolicyn.

7. **Fyll i åldersgränsen** med svaren i samma fil. Resultatet ska bli 4+.

8. **Ladda upp skärmbilderna** ur `appstore/skarmbilder/1206x2622/` i
   nummerordning 01 till 10. Vill du även fylla 6,9-tumsplatsen, ta
   `appstore/skarmbilder/1320x2868/` på samma sätt.

9. **Bygg och ladda upp appen.** Signerat bygge krävs, och det gör `ios.yml`
   inte: den bygger osignerat. Använd `testflight.yml` när du har ett
   Apple Developer-konto och nycklarna på plats. Starta den inte på vinst och
   förlust; gå igenom `TESTFLIGHT.md` först.

10. **Fyll i App Review Information**: namn, telefon, e-post och
    granskningsanteckningen ovan.

11. **Skicka in.** Inget i det här repot laddar upp något till App Store
    Connect, och ingenting har skickats in. Det sista klicket är ditt.
