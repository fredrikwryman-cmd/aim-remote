# App Privacy i App Store Connect · Remote

Det här är svaren du ska fylla i under **App Store Connect → appen → App
Privacy**. Väntat svar på hela avsnittet: **Data Not Collected**.

## Vad du klickar

1. Gå till App Privacy och tryck **Get Started** (eller **Edit** om du redan
   börjat).
2. Första frågan är *Do you or your third-party partners collect data from
   this app?* Svara **No, we do not collect data from this app**.
3. Apple visar då inga fler frågor om datatyper. Tryck **Save** och sedan
   **Publish**.
4. Integritetspolicyns adress fylls i på samma sida om den inte redan står
   där: `https://fredrikwryman-cmd.github.io/aim-remote/site/integritet.html`

Avsnittet **Privacy Choices** (spårning, ATT) lämnas som det är. Appen spårar
inte och ska inte fråga om tillstånd att spåra.

## Motivering

Apples fråga gäller data som lämnar enheten eller som du som utvecklare får
tillgång till. Ingenting av det sker här.

**Ingen server och inget konto.** Appen pratar bara med den TV användaren har
valt, över det lokala nätverket. Det finns ingen backend, ingen inloggning
och ingen tjänst som tar emot något från appen.

**Inga tredjepartsbibliotek.** Appen länkar bara Apples egna ramverk
(SwiftUI, Network, Security, CryptoKit, AVFoundation, WidgetKit) och ett eget
Swift-paket i samma repo, `Packages/AiMCore`. Alltså finns inget analys- eller
annonsnätverk som skulle kunna samla in något i bakgrunden.

**Det appen sparar stannar på telefonen.** TV:ns namn och adress ligger i
UserDefaults i appens app group. Klientens privata nyckel och certifikat,
samt avtrycket av TV:ns certifikat, ligger i iOS nyckelring. Inget av det
skickas någon annanstans, och allt följer med när användaren avinstallerar
appen.

**Mikrofonen är ett undantag värt att förklara.** Appen begär
mikrofontillstånd och skickar ljud, men bara till användarens egen TV och
bara medan användaren själv håller röstinmatningen igång, med en gräns på
femton sekunder. Apple räknar inte det som insamling: ljudet går inte till
utvecklaren och inte till någon tredje part. Att TV:ns egen röstassistent i
sin tur kan skicka ljudet vidare till sin leverantör är TV-tillverkarens
förhållande till användaren, inte appens, och det står skrivet i
integritetspolicyn.

## Integritetsmanifest i bygget

Appen och widgeten har var sin `PrivacyInfo.xcprivacy`:

| Fil | Innehåll |
|---|---|
| `App/PrivacyInfo.xcprivacy` | Ingen spårning, inga insamlade datatyper. Required-reason-API:er: UserDefaults (`CA92.1`) och System boot time (`35F9.1`). |
| `Widget/PrivacyInfo.xcprivacy` | Ingen spårning, inga insamlade datatyper. Required-reason-API: UserDefaults (`AC6B.1`). |

Skälen är valda efter vad koden faktiskt gör:

- **UserDefaults, `CA92.1`** — appen läser och skriver bara sina egna värden
  och värden i sin egen app group.
- **UserDefaults, `AC6B.1`** — widgeten är ett apptillägg som läser samma app
  group som appen den hör till.
- **System boot time, `35F9.1`** — `ProcessInfo.processInfo.systemUptime` i
  `App/UI/Motion.swift`, för att mäta tiden mellan två haptikpulser så att de
  inte går för tätt. Widgeten använder det inte.

Manifesten täcker inget mer, eftersom appen inte rör något mer av Apples
required-reason-API:er. Varken fildatum, ledigt diskutrymme eller aktiva
tangentbord läses någonstans i koden.

Blir manifestet fel märks det vid uppladdningen: App Store Connect skickar ett
mejl om saknade required-reason-API:er, och appen går då att ladda upp men
inte att lämna in. Kommer ett sådant mejl, läs vilket API det handlar om och
hör av dig, så läggs skälet till.
