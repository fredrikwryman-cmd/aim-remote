# TestFlight från molnet

Workflowen `.github/workflows/testflight.yml` bygger, signerar och laddar upp
appen till TestFlight på en macOS-runner hos GitHub. Ingen Mac och ingen sladd
till iPhonen behövs. Den startas bara manuellt.

Förutsättning: medlemskap i Apple Developer Program (1 099 kr/år). Utan det går
det inte att signera för en riktig iPhone eller använda TestFlight.

## Det du gör en gång

### 1. Registrera bundle-id

developer.apple.com → **Certificates, Identifiers & Profiles** → **Identifiers**
→ **+** → **App IDs** → **App** → Continue.

- Description: `Tech Rabbit Remote`
- Bundle ID: **Explicit**, `se.aim.remote`
- Capabilities: inga extra behövs

Register → Confirm. Steget krävs först, annars syns inte bundle-id:t i nästa steg.

### 2. Skapa appen i App Store Connect

appstoreconnect.apple.com → **Apps** → **+** → **New App**.

- Platforms: **iOS**
- Name: `Tech Rabbit Remote` (måste vara ledigt i hela App Store)
- Primary Language: `Swedish`
- Bundle ID: `se.aim.remote`
- SKU: `tech-rabbit-remote`
- User Access: **Full Access**

### 3. Skapa API-nyckel

App Store Connect → **Users and Access** → fliken **Integrations** → **App Store
Connect API** → **Team Keys** → **+**.

- Name: `GitHub Actions TestFlight`
- Access: **Admin**

Generate. Ladda ner `AuthKey_XXXXXXXXXX.p8` — den går bara att hämta en gång.
Skriv av **Key ID** (10 tecken) och **Issuer ID** (ser ut som en UUID) från
samma sida.

### 4. Koda om nyckeln till base64

I PowerShell på Windows, med rätt filnamn:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```

Värdet ligger nu i urklipp.

### 5. Lägg in tre secrets i GitHub

github.com/fredrikwryman-cmd/aim-remote → **Settings** → **Secrets and
variables** → **Actions** → **New repository secret**, en gång per rad:

| Name | Secret |
| --- | --- |
| `ASC_KEY_ID` | Key ID från steg 3 |
| `ASC_ISSUER_ID` | Issuer ID från steg 3 |
| `ASC_KEY_P8` | base64-strängen från steg 4 |

## Varje gång du vill ha ett nytt bygge

1. github.com/fredrikwryman-cmd/aim-remote → **Actions** → **Upload to
   TestFlight** → **Run workflow**.
2. Branch: `main`. Fältet **Team ID** lämnas tomt; workflowen hämtar teamet via
   API-nyckeln. Hittar den inget avbryter den och säger att fältet ska fyllas i
   — Team ID står under *Membership details* på developer.apple.com.
3. **Run workflow**.

Build-numret sätts automatiskt till körningens nummer (`github.run_number`), så
två byggen krockar aldrig i App Store Connect. Versionen ligger kvar på 0.1.0
tills `MARKETING_VERSION` i `project.yml` ändras.

## Efter uppladdningen

1. App Store Connect → appen → **TestFlight**. Bygget står som *Processing* i
   ungefär 5–15 minuter.
2. Exportkravet för kryptering är redan besvarat i `Info.plist`
   (`ITSAppUsesNonExemptEncryption = NO`, appen använder bara vanlig TLS mot
   TV:n), så ingen fråga ska dyka upp.
3. Lägg till dig själv under **Internal Testing** → en grupp → **Testers**.
4. Installera **TestFlight** från App Store på iPhonen, logga in med samma
   Apple-ID och installera bygget därifrån.

Därefter gäller checklistan i `TESTA-PA-TV.md` för första testet mot
TCL 43P635.
