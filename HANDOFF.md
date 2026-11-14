# HEADLINER – Übergabe für einen neuen Claude-Code-Chat

Diese Datei fasst das ganze bisherige Projekt zusammen. **Neuer Chat: bitte zuerst diese Datei, dann `ROADMAP.md` lesen.**

## 1. Was ist das Projekt?
Ein Roblox-Spiel (PC, Spieltexte auf **Englisch**): **HEADLINER – Music Label Tour Manager**.
Man leitet ein Musiklabel, plant Touren für eigene Artists über eine Weltkarte, baut Bühnen in 3D und schaut Konzerte live in 3D.
Ziel: Venues ausverkaufen und die Top-Grossing-Touren-Charts anführen.

**Der User** (spricht Deutsch, Antworten bitte auf Deutsch):
- Hat keine Roblox-Studio-Erfahrung im Scripten. Er bekommt **eine fertige `Headliner.rbxlx`**, öffnet sie in Roblox Studio und drückt Play. Er fügt keinen Code selbst ein. Dateien/Modelle importieren (z. B. 3D-Modelle über den 3D-Importer) kann er.
- Möchte, dass Fakten (z. B. Hallenkapazitäten) mit verlässlichen Quellen recherchiert und Antworten geprüft werden.
- Hat **begrenztes Nutzungskontingent**: Bitte **wenige Zwischen-Updates**, sparsam mit Tokens. Beim Spiel selbst darf viel gemacht werden.
- Echte Namen (Venues/Artists) nur als Parodie (z. B. „The O3“, „Madison Circle Garden“), Artists komplett fiktiv.

## 2. Projektstruktur
```
Headliner.rbxlx          fertige Spieldatei (mit tools/build.py erzeugt)
src/Headliner/           alle ModuleScripts (landen in ReplicatedStorage.Headliner)
  Config.lua             Balancing: Startgeld, Level, Stage-Klassen, Preise
  Data/                  Countries (33 Länder, 247 Venues, Kapazitäten laut Wikipedia), Artists (12),
                         StageItems (Bauteile + Vorlagen), WorldMap (Ländergrenzen, generiert),
                         Regions, Rivals (Charts), Achievements, Reviews
  Logic/                 reines Lua, ohne Roblox testbar: Sim (Nachfrage, Verkauf, Bewertung),
                         GameState (Spielstand, Touren, Level, Kauf/Verkauf), Util
  Client/                App (Steuerung, HUD, Zeit, Popups, Speichern), MainMenu + MenuScene (Hauptmenü mit 3D-Venues),
                         Designer (Stage Builder), Builder (3D-Modelle der Bauteile + Animation), Stage3D (Bauwelt),
                         LiveShow (Konzert), Venue (Halle + Crowd), People (Figuren + Animationen),
                         WorldMap3D (3D-Kartentisch), UI (UI-Bausteine, Farbschema)
  Client/Screens/        Office (Zentrale), Planner (Tourplanung in 4 Schritten), Artists, Tours, Charts
src/server/SaveServer.server.lua   DataStore-Speichern (funktioniert nur in veröffentlichten Places)
src/client/Main.client.lua         Startpunkt
tools/                   Build + Tests (siehe 4.)
ROADMAP.md               offene Wünsche
```

## 3. Was das Spiel bisher kann
- **Hauptmenü:** links Continue / New Game / Store (Platzhalter) / Settings (Lautstärke, Crowd-Detail) / Credits. Rechts läuft nachts eine **Kamerafahrt (~45 s pro Venue, Spline durch Keyframes, Überblendung)** durch drei detaillierte Stadtviertel (`MenuScene.lua`, Maßstab 1 Stud ≈ 0,5 m):
  - **The O3** (London): Kuppel 365 m / ~50 m hoch mit Seilnetz, 12 gelbe geneigte Masten (~100 m) mit Abspannungen, „Up at the O3“-Steg, Glas-Eingang mit O-Logo, LED-Screens, Queues, Foodtrucks, Station + Busbahnhof, Black Cabs und rote Doppeldecker, Seilbahn über die Themse mit Gondeln, Boote, Canary Wharf (Pyramidenturm), Stahlwolken-Skulptur. Flug: zwischen Canary-Wharf-Türmen über die Themse, über das Dach, zum Eingang.
  - **Madison Circle Garden** (New York): echtes Straßenraster (7th/8th Ave, 28th–42nd St, MSG zwischen 31st und 33rd), Trommel ~123 m mit 48 Finnen, Dachseilen und Lichtband, Glas-Pavillon mit Marquee und LED, Two-Penn-Turm, Farley-Gebäude mit Säulen, Empire-State-artiger Turm (Krone in Artist-Farbe). Straßen: Ampeln an Auslegern, Zebrastreifen, Busspur, Dampfschlote mit Rauch, U-Bahn-Eingänge, Baugerüste, Wassertürme, Läden mit Markisen, Blade-Billboards, Nadel-und-Knopf-Skulptur, fahrende Taxis/Busse (Einbahnrichtungen wie echt), Fußgänger. Flug: die 7th Ave hinunter, über die 33rd St, um die Trommel, zum Eingang.
  - **Lanxus Arena** (Köln): Dom (Doppeltürme 157 m, Strebewerk, Fenster), Altstadthäuser mit Giebeln, Romanik-Turm, blaues Musical-Zelt, Eisenbahnbrücke (3 Bögen je Feld) mit fahrenden ICEs, Bahnhof Messe/Deutz, Glas-Hochhaus, Rheinboulevard-Treppe mit Leuten, Deutz mit Straßenbahnen, Arena mit Rundenden, Glasfassade und 76-m-Bogen mit Hängern, Vorplatz mit Fans, Kölsch-Stand. Flug: vom Dom über die Brücke, durch Deutz, zur Arena.
  - Technik: Gebäude-Baukasten mit LOD nach Abstand zur Flugbahn, Höhen werden automatisch unter der Flugbahn gekappt (keine Kollision), Budgets für Lichter/SurfaceGuis, ~4k/12k/6k Parts. Suchscheinwerfer, blinkende Flugwarnlichter, wechselnde LED-Texte, Bloom.
- **Neues Spiel:** Label benennen, einen von 3 Start-Artists wählen. **Büro** als Zentrale mit Kacheln, nächsten Shows und News.
- **Fortschritt:** 5 Label-Level nach verkauften Tickets. Größere Artists erst ab höherem Level.
- **Tourplanung (4 Schritte):** Artist, dann Route (3D-Weltkarte mit Länder-Hover, Venue-Filter Club/Theater/Arena/Stadion, Promoter-Schätzungen statt Garantien), dann ein Ticketpreis pro Tour und eine Bühnenproduktion **pro Hallengröße**, dann Bestätigen.
- **Simulation:** Nachfrage pro Land (Fans, Hype, Genre-Vorlieben, Preis), versteckte ±25 % Abweichung, Vorverkauf über Zeit, Marketing, Kosten (Miete, Produktion 8 % des Equipmentwerts, Reisen, 35 % Artist-Anteil), Bewertungen, Fanwachstum, Achievements, Charts.
- **Stage Builder (neu, Stil wie Theme Park Tycoon 2):** Katalog unten (Kategorien Stage / Artist / Lights / Screens / Effects / Set Pieces, Karten mit 3D-Bild + Preis), Werkzeugleiste darüber (Grid, Dreh-Raster 15/45/90°, Drehen, Kopieren, Löschen, ✕, ✓ PLACE). Ablauf: Karte wählen → in die Welt klicken → Teil steht „noch nicht gekauft“ (grün) → mit Gizmo ausrichten (rot X, blau Z, grün Höhe = `rec.yo`, oranger Ring drehen, goldene Würfel Größe) → ✓ kauft. Inspector rechts nur bei Auswahl. Preis am Mauszeiger. „?“ zeigt die Steuerung.
- **MY STAGES (Bibliothek, `Screens/StagesScreen.lua`):** Karten mit 3D-Vorschau, Songs/Items/Kosten, ON TOUR/STARTER, Edit/Copy/Delete. Dialog „New stage“: Größe, Typ, Start (leer, Basis-Deck oder Vorlage).
- **Vorlagen aus echten Touren** (`StageItems.PRESETS`, `shop = true` kostet): The Cube (in-the-round, LED-Würfel, 8 LED-Türme, Armbänder – angelehnt an Billie Eilish HMHAS / Metallica M72), Portal Ring (Portal + Roboterarme – angelehnt an Beyoncé Renaissance), Runway & Moon (Skyline, Laufsteg, Mond, Statue – angelehnt an The Weeknd).
- **Setlist = Anzahl Artist-Spots** (3–12, ohne Spots 4). Spot n = Song n, Reihenfolge im Inspector („Earlier/Later“). Lift/Piano/Keys/Drums/DJ „in Song n“. Screens: Inhalt für die ganze Show + Änderungen pro Song.
- **Live-Kamera auf Screens** (`Client/LiveFeed.lua`): eigene 3D-Szene im ViewportFrame: Artist (Kopien der Figuren, Kamera kreist) oder Fans (Crowd mit Armen, Lightsticks, Handys, Kamera schwenkt).
- **Stage Designer (alte Funktionen, weiterhin vorhanden):**
  - Größenklassen Club/Theatre/Arena/Stadium, End Stage oder Center Stage.
  - Freie Decks (Rechteck/Dreieck/Ecke/Rund/Treppe) mit Größe, Höhe, Drehung und Oberflächen (inkl. LED), Kantenlicht optional, „Set all decks“.
  - Roblox-Handles zum Verschieben/Skalieren/Drehen, Grid 1/2/4/8, Kopieren parallel daneben.
  - Lichter rasten an Truss ein.
  - Screen-Editor pro Spot: Songtitel, Artist, Text, Bild-ID, Live-Kamera Artist oder Crowd. „Set all screens“.
  - Artist-Spots 1–4, Lift als eigener Spot, „Artist spielt“ Piano/Drums/DJ-Pult.
  - Leere Venue-Kulisse, Equipment kaufen und für 70 % verkaufen, Vorlagen geschützt (Clear/Restore).
- **Neue Props:** Kinetic Light Bars, LED Cube, LED Tower, LED Pillar, Portal Ring, Streamer, Low Fog, Giant Balloons (fliegen in die Crowd), LED Wristbands (Crowd leuchtet in Wellen), Kabuki Curtain (fällt zum ersten Song), Giant Moon, City Skyline, Giant Statue, Robot Arm, Little House, Light Arch, Flower Garden, Keyboard Rig, Mic Stand, Amp Stack.
- **Mehrere Nächte pro Venue:** in der Route „- 2 nights +“; Nächte am selben Ort sind aufeinanderfolgende Tage, keine Reisekosten (`GS.scheduleDays`).
- **SOCIAL-Tab** (`Data/Social.lua`, `Logic/Social.lua`, `Screens/SocialScreen.lua`): Fan-Posts zu Ankündigung, Preisen, Sold-outs, schwachem Verkauf, Shows (je nach Sternen), Fotos, Fanprojekten, Setlist, Outfits, Bühnenmomenten, Merch, Absagen. Fan-Stimmung pro Artist, Trending-Hashtags.
- **Eigene Looks pro Artist** (`Artists.look`, Band-Stile pro Genre), 3D-Figur in Artist-Karten, Starter-Auswahl, Planer und Büro.
- **UI aufgeräumt:** feste Navigationsleiste oben (Office, Artists, Tours, Stages, Social, Charts, + Plan a Tour), Büro mit „Next show“ statt Kachel-Wand, Artist-Karten ohne Regionsbalken.
- **Live-Show (Länge je nach Songs, Speed 1x/2x/4x, Skip):**
  - Jede Show hat einen anderen Ablauf (4 Songs aus 8, Ballade mit Handylichtern an wechselnder Stelle, Zugabe-Pause, Effekte).
  - Wegfindung über Decks/Treppen, Lift-Auftritte, viele Animationen.
  - Venue-Typen Club/Theater/Arena/Amphi/Stadion mit Details (FOH-Zelt, Bar, Videowürfel, Flutlicht).
  - Crowd-Größe entspricht den verkauften Tickets.

## 4. Werkzeuge (wichtig, weil man Roblox in der Cloud nicht starten kann)
Voraussetzungen: `pip install lupa luaparser shapely global-land-mask` (PyPI erreichbar), Node mit Playwright ist vorinstalliert.
GitHub-Releases und crates.io waren in der Cloud gesperrt. npm und PyPI gehen.
```bash
python3 tools/build.py                               # baut Headliner.rbxlx aus src/
python3 tools/test_logic.py                          # Logik-Tests (Lua 5.1 via lupa)
# Roblox-API-Liste holen (einmalig):
V=$(curl -sS https://setup.rbxcdn.com/versionQTStudio); curl -sS -o api-dump.json "https://setup.rbxcdn.com/$V-API-Dump.json"
python3 tools/check.py api-dump.json                 # Syntax, undefinierte Variablen, Klassen/Properties/Enums/Methoden
python3 tools/gen_api_lua.py api-dump.json api_classes.lua
python3 tools/run_mock.py api_classes.lua tools/scenario_full.lua   # spielt das ganze Spiel in einer Roblox-Attrappe durch
python3 tools/screens.py api_classes.lua <ordner>    # rendert alle Menüs als HTML + PNG (nutzt Node-Playwright, tools/shoot_html.js)
# 3D-Vorschau der Hauptmenü-Kamerafahrten und der Bühnen-Vorlagen (three.js + Playwright), siehe tools/render3d/README.md
# Hinweis: Die Attrappe (mock_roblox.lua) bewegt bei Model:PivotTo jetzt alle Teile wie Roblox.
# Weltkarte neu erzeugen: npm pack world-atlas@2.0.2 → countries-50m.json
python3 tools/gen_worldmap.py <pfad>/countries-50m.json
```
**Regeln, die sich bewährt haben:**
- Code in **Lua-5.1-kompatiblem Luau** schreiben (keine `+=`, keine Typannotationen, kein `continue`), sonst schlägt der Syntax-Check fehl.
- `string.format("%d")` nur mit ganzen Zahlen und `math.clamp` nie mit min > max: Luau ist dort strenger.
- Lua-Schlüsselwörter als Tabellenschlüssel (z. B. Land „in“) mit `["in"]` schreiben.
- Dateien bei Python-Patches erst in eine Temp-Datei schreiben und dann ersetzen. Einmal wurde `Designer.lua` dabei geleert und musste aus der `.rbxlx` gerettet werden.
- Vor dem Ausliefern immer: `check.py`, `test_logic.py`, `run_mock.py` (Ergebnis „OK – no runtime errors“), dann `build.py`.

## 5. Offenes Feedback und nächste Schritte (Priorität von oben)
1. **Hauptmenü-Venues: neu gebaut (Stadtviertel + Kamerafahrt), Feedback des Users abwarten.** Mögliche nächste Schritte: Performance auf schwachen PCs prüfen (Manhattan ~12k Parts, Aufbau während der Schwarzblende), ggf. Detail an „Crowd detail“-Setting koppeln; weitere Venues; echte Meshes (OBJ/FBX) für noch feinere Fassaden.
2. **Feedback des Users zum neuen Stage Builder, Social-Tab, Live-Screens und Looks abwarten** (großer Umbau, Nov 2026).
3. **Büro mit Roblox-Charakter**, der sich an den PC setzt. Das Label-Menü läuft „im PC“.
4. Später: **Musik** pro Artist (User will Songs erst, wenn die Basis steht), Hörprobe bei der Auswahl.
5. Balancing beobachten: User hat bisher alles ausverkauft (Clubs). Leere bei schwachem Verkauf funktioniert (Crowd = verkaufte Tickets), wurde aber noch nicht gesehen.

## 6. Bekannte Grenzen
- Speichern geht nur, wenn der Place veröffentlicht ist (DataStore).
- Musik fehlt noch, weil Roblox-Audio hochgeladen werden muss.
- Die Live-Kamera auf Screens funktioniert nur während Show/Vorschau.
