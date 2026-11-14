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
- **Hauptmenü:** links Continue / New Game / Store (Platzhalter) / Settings (Lautstärke, Crowd-Detail) / Credits. Rechts kreist eine Kamera nachts um nachgebaute Venues (The O3, Madison Circle Garden, Lanxus Arena) mit Stadt, Fans und Bannern.
- **Neues Spiel:** Label benennen, einen von 3 Start-Artists wählen. **Büro** als Zentrale mit Kacheln, nächsten Shows und News.
- **Fortschritt:** 5 Label-Level nach verkauften Tickets. Größere Artists erst ab höherem Level.
- **Tourplanung (4 Schritte):** Artist, dann Route (3D-Weltkarte mit Länder-Hover, Venue-Filter Club/Theater/Arena/Stadion, Promoter-Schätzungen statt Garantien), dann ein Ticketpreis pro Tour und eine Bühnenproduktion **pro Hallengröße**, dann Bestätigen.
- **Simulation:** Nachfrage pro Land (Fans, Hype, Genre-Vorlieben, Preis), versteckte ±25 % Abweichung, Vorverkauf über Zeit, Marketing, Kosten (Miete, Produktion 8 % des Equipmentwerts, Reisen, 35 % Artist-Anteil), Bewertungen, Fanwachstum, Achievements, Charts.
- **Stage Designer:**
  - Größenklassen Club/Theatre/Arena/Stadium, End Stage oder Center Stage.
  - Freie Decks (Rechteck/Dreieck/Ecke/Rund/Treppe) mit Größe, Höhe, Drehung und Oberflächen (inkl. LED), Kantenlicht optional, „Set all decks“.
  - Roblox-Handles zum Verschieben/Skalieren/Drehen, Grid 1/2/4/8, Kopieren parallel daneben.
  - Lichter rasten an Truss ein.
  - Screen-Editor pro Spot: Songtitel, Artist, Text, Bild-ID, Live-Kamera Artist oder Crowd. „Set all screens“.
  - Artist-Spots 1–4, Lift als eigener Spot, „Artist spielt“ Piano/Drums/DJ-Pult.
  - Leere Venue-Kulisse, Equipment kaufen und für 70 % verkaufen, Vorlagen geschützt (Clear/Restore).
- **Live-Show (~80–90 s, Speed 1x/2x/4x, Skip):**
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
python3 tools/screens.py api_classes.lua <ordner>    # rendert alle Menüs als HTML (danach mit Playwright screenshotten)
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
1. **Hauptmenü-Venues viel detaillierter.** Der User findet sie noch „lazy“. Gewünscht:
   - Wirklich detaillierte Nachbauten mit Fassaden, Eingängen, Dachdetails, belebter Umgebung und Stadt.
   - Mehrere Hallen und eine Kamerafahrt, die durch die Straßen/zwischen Gebäuden fliegt (z. B. Madison Circle Garden durch Manhattan).
   - **Idee:** Detail-Modelle extern als Meshes erzeugen (z. B. OBJ/FBX per Python oder Blender, falls installierbar). Der User importiert sie mit dem Roblox-3D-Importer und gibt die Asset-IDs bzw. das Modell weiter. Alternativ deutlich mehr Parts mit Teil-Bausteinen.
2. **Büro mit Roblox-Charakter**, der sich an den PC setzt. Das Label-Menü läuft „im PC“.
3. **Social-Media-Feed** zu Touren (positive und negative Kommentare je nach Erfolg).
4. **Eigener Look pro Artist/Band** (Outfits, Frisuren), Vorschau bei der Auswahl, später Hörprobe.
5. Später: **Musik** pro Artist, **Setlist-Editor**.
6. Den Lift-, Screen- und Wegfindungs-Fix (zuletzt gebaut) mit dem User verifizieren.

## 6. Bekannte Grenzen
- Speichern geht nur, wenn der Place veröffentlicht ist (DataStore).
- Musik fehlt noch, weil Roblox-Audio hochgeladen werden muss.
- Die Live-Kamera auf Screens funktioniert nur während Show/Vorschau.
