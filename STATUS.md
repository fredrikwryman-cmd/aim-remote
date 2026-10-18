# Status – AiM Remote

2026-10-18

- Skrivet: native iPhone-projekt, två huvudvyer, lokal TV-sökning, parkoppling, kommandon, tangentbord, mikrofon och återanslutning.
- Skrivet: tester för protokoll, certifikat och gränssnitt; molnbygge med Xcode.
- Genomfört: Swift-syntaxkontroll på Windows, utan syntaxfel i de 14 Swift-filerna vid första kontrollen.
- Återstår: Xcode-kompilering och körning av testerna, signerad installation och fysisk test på TCL 43P635.
- Ingen faktisk TV-anslutning har ännu gjorts från AiM Remote.
- Genomfört: plist, XcodeGen-konfiguration, workflow-YAML och resurs-JSON kontrollerade på Windows.
- Molnbygge: blockerat i väntan på uttryckligt godkännande att skapa det privata GitHub-projektet `fredrikwryman-cmd/aim-remote` och ladda upp appkoden. Automatisk säkerhetsgranskning avvisade exporten eftersom detta mål inte uttryckligen hade godkänts. Repository skapades inte och inget bygge startades.
- När uppladdningen godkänts: skapa privat repository, skicka koden, kör arbetsgången, rätta eventuella Xcode-/testfel och hämta IPA-filen. En källkod-ZIP är ännu inte en installerbar iPhone-app.
