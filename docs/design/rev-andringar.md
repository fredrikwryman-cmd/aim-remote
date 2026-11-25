# Ändringslista enligt rev-ux · TechRabbit Remote

Endast BETEENDE: rörelse, haptik, flöden och tillstånd. Inga färger, typsnitt, former, mått eller skyddade tillgångar ändras. Inga funktioner läggs till eller tas bort. Utseendet följer PDF-facit som i dag.

**GODKÄND AV FREDRIK 25 nov 2026: alla punkter 1–19 JA.**

## A. Tryck och haptik
1. **Alla tangenter trycks ned likadant.** Skalning 0.97 med snabb fjäder på varje tryckbar yta: tangenter, vippor, rader i Inställningar, flikar och Anslut-pillret. Visuell respons inom 100 ms. (Finns delvis i dag på tangenterna.)
2. **Haptik enligt en karta**, samlad på ett ställe:
   - Fjärrtangenter och vippor: rigid vid varje tryck, även vid hållrepetition.
   - Flikbyte och val i listor: selection.
   - Panel snäpper upp eller ned: soft.
   - Ansluten: success. Fel eller tappad anslutning: error, en gång.
   - Före Glöm TV: warning.
   - Aldrig två inom 80 ms, och aldrig vid scroll.
3. **Av-knapp för haptik** i Inställningar respekteras överallt. (Raden Knappvibration finns redan, men den ska styra all haptik, inte bara tangenterna.)

## B. Anslutningens tillstånd
4. **Tydligt byte mellan lägen** (A8). När statusen går mellan Inte ansluten, Ansluter, Ansluten och Offline:
   - pricken och texten byter med crossfade på 160 ms
   - under Ansluter pulserar pricken lugnt
   - vid Ansluten blinkar pricken en gång i accentfärgen, med haptik
5. **Anslut-pillret visar vad som händer.** Det byter text Anslut → Ansluter… → döljs när anslutningen är klar, med en mjuk breddanimation i stället för att hoppa. Vid fel kommer det tillbaka som "Försök igen".
6. **Felmeddelanden enligt mallen** "vad hände · vad betyder det · vad gör jag nu". Exempel: "Hittar inte TV:n. Den kan vara avstängd eller på ett annat wifi. Starta TV:n och tryck Försök igen." Ingen ruta för automatiska omförsök, bara statusraden.

## C. Paneler och ark
7. **Paneler växer ur knappen du tryckte på** (123, Tangentbord, TV-ikonen till Välj TV, Hjälp). Sidan bakom sjunker till 0.94 och mörknar, i stället för att panelen bara dyker upp.
8. **Paneler följer fingret.** Dra nedåt för att stänga. Släpper du före halva vägen fjädrar panelen tillbaka. Haptik soft vid snäpp.
9. **Ordning in:** rubrik, innehåll med 35 ms förskjutning, stängknapp sist. Ut i omvänd ordning på ungefär 70 % av tiden.
10. **Stäng-knappen och nedsvep fungerar mitt i animationen.** Inget blockerar.

## D. Välj TV och parkoppling
11. **Laddningsskelett i stället för snurra** när TV:ar söks: två eller tre rader i rätt form som skimrar lugnt, tills de första TV:arna dyker upp. Nya TV:ar glider in i listan med layoutanimation, utan att hoppa.
12. **Tomt läge:** om inga TV:ar hittas efter ungefär 8 sekunder visas en förklaring ("Ingen TV hittades. Kontrollera att TV:n är på och på samma wifi.") och en knapp "Sök igen".
13. **Parkopplingskoden:** fältet skakar kort med haptik error vid fel kod. Vid rätt kod landar TV:n i listan som "Ansluten", med haptik success. Det är firaögonblicket, men utan konfetti.
14. **Glöm TV:** bekräftelseark med konsekvensen i klartext ("Du måste skriva in koden från TV:n igen för att ansluta") och knappen Glöm sist, markerad. Haptik warning när arket öppnas.

## E. Skärmbyten och scroll
15. **Flikbyte:** crossfade 160 ms med 8 pt glidning uppåt, och flikens ikon studsar lätt. Haptik selection.
16. **Inställningar:** rubriken krymper in i toppfältet när du scrollar, och toppfältet får sin avdelare först när innehåll ligger under det.
17. **Kort entré** när appen öppnas igen: fjärren tonar in från skala 1.04 till 1 på ungefär 300 ms. Ingen lång startanimation.

## F. Tillgänglighet och integritet
18. **Reducerad rörelse överallt:** förflyttning, skalning och puls ersätts av crossfade 160 ms. Haptiken ligger kvar.
19. **Största textstorlek:** etiketter krymper men klipps inte. VoiceOver läser statusen ("Ansluten till TCL 43P635").
20. **Ingen blur i app-växlaren.** Appen visar inget känsligt, så den här punkten utelämnas medvetet.

## Inte med (medvetet)
- Ingen startsida med huvudvärde, händelseström eller sök. Fjärren är huvudvärdet, och PDF-facit gäller.
- Inga nya flikar, widgets eller funktioner.
- Inga bankmönster.
