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

2. **Sid 1 och sid 2 har inte samma mått.** Panelen är 15 pt från kanten och
   519,5 pt hög i sid 1, men 11 pt från kanten och 555,5 pt hög i sid 2.
   Vippan är ett hölje med två tangenter i sid 1 och en enda kapsel i sid 2.
   Toppkortets yta och flikradens hölje ritas bara i de ljusa sidorna. Appen
   följer respektive sida, så fjärren byter marginal, panelhöjd och vippa när
   telefonen byter läge. Inställningar har samma mått i sid 3 och sid 4.

3. **Skenet i nedre vänstra hörnet** är något grönare i appen än i facit, som
   mest 12 av 255 vid (50, 830). Övriga uppmätta bakgrundspunkter ligger inom
   2–10. Mörkt läge har inget sken alls, bara en lodrät toning.

4. **Tangenterna** ritas i full styrka även utan ansluten TV, som i facit.
   Spärren sitter kvar, så utan anslutning skickas inget.

5. **TV-ikonen ritas som egen glyf.** SF-symbolen `tv` ritas av iOS med fylld
   skärm; facit har en kontur med fot. Glyfen ritas därför i `TRDisplayIcon`.

## Uppmätta mått, ljust läge (390 x 844, facit sid 1 och sid 3)

Mörkt läge mäts i sid 2 och sid 4; värdena står i `TR.Layout.dark`.

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
