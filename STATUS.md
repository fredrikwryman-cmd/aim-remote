# Status – Tech Rabbit Remote

Uppdaterat 2026-10-19.

## Klart

- Privat GitHub-projekt skapat efter användarens uttryckliga godkännande: https://github.com/fredrikwryman-cmd/aim-remote
- iPhone-app för iOS 16.4 eller senare byggd med Xcode 15.4 på macOS.
- 10 protokolltester, 3 tester av nyckelring/certifikat och 1 test av de två huvudvyerna passerade, utan fel.
- Simulatorbilder exporterade och visuellt granskade. Fjärr och Inställningar visas utan överlapp mellan kontrollerna på testad iPhone 15.
- Osignerad IPA hämtad till `../AiM-Remote-build/AiM-Remote-unsigned.ipa` och kontrollerad: giltig ZIP, iPhoneOS/arm64-program, rätt appnamn och version.

## Byggbevis

- Godkänt bygge: https://github.com/fredrikwryman-cmd/aim-remote/actions/runs/39295761974
- Testad appkod: commit `940d1f1`.
- Export av befintliga testbilder: https://github.com/fredrikwryman-cmd/aim-remote/actions/runs/39296440739
- IPA SHA-256: `add2fff73bbd6f240ff2f18a355dcc6c98d27c2f1c3877c8ec2e19b41ce52890`
- Storlek: 337559 byte. Version 0.1.0, build 1, bundle ID `se.aim.remote`.

## Återstår

- Signera och installera IPA-filen på användarens iPhone via Windows, exempelvis med Sideloadly. En osignerad IPA kan inte installeras direkt genom att öppna filen på iPhone.
- Fysisk parkoppling och funktionstest med TCL 43P635. Ingen faktisk TV-anslutning har ännu gjorts från Tech Rabbit Remote.
- Bekräfta särskilt mikrofon, textinmatning, kanalknappar och väckning från standby på den verkliga TV:n och dess appar.

## Rättat under bygget

- XcodeGen-projektformat anpassat till Xcode 15.4.
- Explicit fångst av anslutningsobjektet vid växling till huvudtråden.
- Simulatorbygget signeras lokalt med rätt nyckelringsbehörighet. Dessa simulatorbehörigheter används inte för iPhone-paketet; riktig signering sker vid installationen.

Referensbilder och TV-serienummer har inte laddats upp till GitHub.
