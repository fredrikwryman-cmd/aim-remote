# Avvikelser mot facit — Tech Rabbit Remote

Facit: `tr-remote-design-v1/TechRabbit-Remote-design-v1/` (SPEC.md, tokens.json,
skarmar/R01–R04) samt `design/referenser/TR-Remote-selection.png`.
App: simulatorbilder 390 × 844 ur `screenshots.yml`.

Alla mått i pt. Facitbildernas innehåll ligger i 390 × 844-koordinater; app-måtten
är uppmätta i skärmbilderna med pixelanalys (OK-tangenten, panelens kant,
swooshens läge) och resten lästa ur koden.

Sorterad efter hur mycket avvikelsen syns.

| # | Skärm | Element | Egenskap | Facit | App (före) | Status |
|---|-------|---------|----------|-------|-----------|--------|
| 1 | R02 | Alla tangenter i fjärrpanelen | storlek | fasta pt-mått (OK 82 × 74) | skalade upp 1,26 ggr efter skärmhöjden (OK 84 × 93) | rättad |
| 2 | R02 | D-padens rader | avstånd | 82 mellan radernas mitt (72 + gap 10) | 72, inget gap | rättad |
| 3 | R02 | Kanal- och volymvippan | höjd | 140 | 176 | rättad (följer 1) |
| 4 | R02 | 2 × 2-rutnätets tangenter | höjd | 52 | 66 | rättad (följer 1) |
| 5 | R02 | Mediaraden | höjd | 44 | 55 | rättad (följer 1) |
| 6 | R02 | Fjärrpanelen | höjd | 472 (12 + 140 + 14 + 236 + 14 + 44 + 12) | 564 | rättad (följer 1) |
| 7 | R02 | Inre avstånd i panelen | gap | 14 mellan blocken, 10 mellan tangenter | 17,7 och 12,6 | rättad (följer 1) |
| 8 | R02 | Flikraden | antal flikar | fyra lika breda: Fjärr, Enheter, Scener, Inställningar | två: Fjärr, Inställningar | ej rättad — motsägelse, se nedan |
| 9 | R02 | Flikraden | ikon Inställningar | sol/stjärna | `slider.horizontal.3` (facits Scener-ikon) | ej rättad — hör ihop med 8 |
| 10 | R02 | Flikraden | avstånd till botten | 30 ovanför safe area | 12 ovanför safe area (≈ 46 från skärmkanten) | ej rättad — motsägelse, se nedan |
| 11 | R02 | 2 × 2-rutnätet | läge i raden | rutnätet ligger ≈ 10 lägre än mitten av 140-raden | centrerat i raden | ej rättad — facit tyst, se nedan |
| 12 | R02 | Huvudrad och panel | överkant | panelens kant 161 (statusrad ≈ 59) | 157 (safe area top 47 i simulatorn) | ej rättad — motsägelse, se nedan |
| 13 | R02 | Panelens inre överkant | avstånd | vippan börjar 16 under panelens kant, d-paden 37 under vippan | 12 respektive 14, enligt SPEC | ej rättad — motsägelse, se nedan |
| 14 | R02 | TV-ikonknappen | ikon | tunn konturskärm | fylld skärm (SF Symbol `tv` i nyare SF-version) | ej rättad — plattformens symbol, inget eget val |
| 15 | R02 | Tangenten TV-inställningar | ikon | solliknande glyf i facitbilden | `gearshape` | ej rättad — facitbild mot SPEC-text, se nedan |
| 16 | R02 | Statusrad och tangenter | tillstånd | "Ansluten", tangenter fullt synliga | "Inte ansluten", tangenter 0,4 enligt SPEC:s tillståndslista | ingen avvikelse — simulatorn hittar ingen TV |
| 17 | R01 | Hela skärmen | allt | symbol 96 vid 220, rubrik 34/40, underrad 17, knapp 64 vid 580 | samma | ingen avvikelse |
| 18 | R02 | Swooshen | läge | kurvan möter högerkanten vid y 380 | samma (uppmätt 386,3 vid x 384 i båda) | ingen avvikelse |
| 19 | R02 | OK-tangenten | bredd | 82 | 82 (84 med 2 pt kant) | ingen avvikelse |
| 20 | R02 | Sidomarginal | marginal | 18 | 18 | ingen avvikelse |
| 21 | R03, R04, panelerna | — | — | — | — | ej jämförda mot bild, se nedan |

## Det som inte rättats, och varför

**8 och 9 — flikraden.** SPEC kräver fyra flikar (Fjärr, Enheter, Scener,
Inställningar). Enheter och Scener är inte byggda, och `ScreenTests` slår
uttryckligen fast att de inte finns. Att lägga till dem är en funktionsändring
och att ta bort testet är förbjudet enligt direktivet. Lämnas som motsägelse
mellan facit och byggd omfattning.

**10 — flikradens avstånd till botten.** SPEC säger 30 ovanför safe area. Appen
drar av hemindikatorns 34 och landar på 12. Facitbilden har ingen safe area att
mäta mot, så vilket av måtten som avses går inte att avgöra ur facit.

**11 — 2 × 2-rutnätets läge.** Facitbilden lägger rutnätet ≈ 10 pt lägre än
mitten av raden. SPEC säger bara "i mitten ett 2 × 2-rutnät". Inget mått finns,
alltså inget att rätta mot.

**12 och 13 — innehållets överkant och panelens inre avstånd.** SPEC säger
"innehållet börjar under statusraden (safe area top)", padding 12 och inre gap
14. Facitbilden är ritad med en statusrad på ≈ 59 och med 16 respektive 37 inne
i panelen. SPEC-texten och facitbilden säger alltså olika saker. Koden följer
SPEC-texten. Rättas inte.

**14 — TV-ikonen.** `tv` ur SF Symbols ritas olika i olika iOS-versioner. Att
byta till en egen ikon vore ett eget designbeslut.

**15 — ikonen på TV-inställningar.** SPEC-texten säger "TV-inställningar"
(kugghjul), facitbilden ritar en solliknande glyf. Motsägelse inom facit.

**21 — R03, R04 och panelerna.** Facit har bild bara för R01, R02 (ljust och
mörkt), R03 mörkt och R04 mörkt. För panelerna TV och anslutning, 123,
Tangentbord och Hjälp finns ingen facitbild alls och inget avsnitt i SPEC, bara
de gemensamma reglerna. De fotograferas nu av `DesignShotTests` men kan bara
jämföras mot SPEC:s gemensamma del.

## Otydligt i facit

1. SPEC R02: "D-pad, grid 3 × 82 kolumner och 4 × 72 rader" men listar tre
   rader. Fyra rader stämmer bara om mediaraden räknas in, och den är 44 hög,
   inte 72. Uppmätt i facitbilden: tre rader med 82 mellan mitterna.
2. SPEC säger safe area top; facitbilden är ritad med statusrad 59, och
   tokens.json anger `statusBar: 54`. Tre olika värden.
3. tokens.json har `radius.phoneContent: 0`, men facitbilderna är ritade med
   rundade hörn och en tunn ram.
4. Facitbilderna visar tillståndet "Ansluten". Hur panelen ska se ut i
   simulatorn, som aldrig hittar en TV, står bara i SPEC:s textavsnitt
   "Tillstånd som inte har egen bild".
5. Ljusa lägen finns som facitbild bara för R02. R01, R03 och R04 har bara
   mörkt läge.
