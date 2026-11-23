# Avvikelser mot facit

Facit: PDF:en "Tech Rabbit Remote", renderad till `design/referenser/v2/`.
Jämförelsebilder: `design/jamforelse/v2/` (facit till vänster, appen till
höger, 390 x 844).

Mätt i facit sid 1 (Fjärr ljust) och sid 3 (Inställningar ljust). Sid 2 och
sid 4 är samma layout i mörkt läge. Sid 5 är designsystemet.

## Kvarvarande skillnader

1. **Över- och underkant.** Facit är ritad på en 390 x 844-duk utan
   statusfält och hemindikator. Appen lägger innehållet innanför den säkra
   ytan, så toppkortet börjar under statusfältet och flikraden slutar ovanför
   hemindikatorn. Panelen behåller facit-proportionerna och skalas i höjd för
   att fylla ytan däremellan. Detta är den avvikelse direktivet tillåter.

2. **Tangenterna är nedtonade när ingen TV är ansluten.** Facit ritar varje
   tangent i full styrka trots statusraden "Inte ansluten". Appen håller kvar
   `.disabled(!connection.ready)`, som både gör tangenten overksam och tonar
   ned den enligt knappstaten Disabled på sid 5. Att ta bort den hade ändrat
   anslutningsfunktionen, vilket direktivet förbjuder. Skärmbilderna tas i en
   simulator utan TV, så de visar alltid det nedtonade läget; på en telefon
   med sparad TV är tangenterna i full styrka.

3. **Toppkortet och flikraden ritas olika i ljust och mörkt läge.** Facit sid
   1 har ett kort bakom av/på-knappen och ett vitt hölje med grön ruta kring
   vald flik. Sid 2 har varken kort eller hölje: huvudet och flikarna ligger
   direkt på bakgrunden och vald flik markeras bara med accentfärgen. Appen
   följer respektive sida.

4. **Sid 1 och sid 2 har inte exakt samma mått.** Panelen är 15 pt från
   kanten och 519,5 pt hög i sid 1, men 11 pt från kanten och 555,5 pt hög i
   sid 2. Appen följer sid 1, som är den enda sidan med symmetrisk innerram
   (16 pt upptill, 21,5 pt nedtill).

5. **TV-ikonen ritas som egen glyf.** SF-symbolen `tv` ritas av iOS med fylld
   skärm; facit har en kontur med fot. Glyfen ritas därför i `TRDisplayIcon`.

## Uppmätta mått (390 x 844, facit sid 1 och sid 3)

| Del | Mått |
| --- | --- |
| Sidmarginal | 15 |
| Toppkort | 70 högt, radie 35, inre marginal 15 |
| Av/på-knapp | 50 |
| Statusrad | 33 hög, indrag 12, pillerradie 16,5 |
| Panel | 360 x 519,5, radie 34, inre marginal 11 / 16 / 21,5 |
| Vippa | 76 x 127, radie 38, två tangenter 68 x 48 |
| 2 x 2-tangent | 73 x 45, radie 22 |
| Kolumnmellanrum | 13,5 |
| D-pad | 84,5 x 84,5, radie 26, kolumnmellanrum 42, radmellanrum 10,5 |
| Mediatangent | 74,5 x 49, kapsel |
| Flikrad | 72 hög, radie 36, inre marginal 8 |
| Hero-kort | 99 högt, radie 28, ikon 60, radie 17 |
| Inställningsrad | 57 hög, inre marginal 20, ikon 26 |
