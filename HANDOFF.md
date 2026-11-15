# HEADLINER – Übergabe für einen neuen Claude-Code-Chat

Diese Datei fasst das ganze bisherige Projekt zusammen. **Neuer Chat: bitte zuerst diese Datei, dann `ROADMAP.md` lesen.**


## 0. NEU (Nov 2026): Begehbares Label statt Tab-Menü – ZUERST LESEN
Das Spiel läuft jetzt mit Spielfigur in einer Welt. Die Menüs sind Orte (Stationen mit ProximityPrompt „E“).
- **Server hält den Spielstand** (`src/server/GameServer.server.lua`): lädt/speichert (DataStore, Sandbox mit eigenem Schlüssel `player_<id>_sandbox`), baut das Gebäude, führt alle Aktionen aus. Alle Änderungen laufen über `Logic/Actions.lua` (reines Lua, getestet). Der Client fragt per RemoteFunction `Remotes.Action` (Argumente als JSON) und bekommt nur geänderte Top-Level-Schlüssel zurück (`delta`), die per `Util.syncInto` in `app.state` kopiert werden (Tabellen bleiben dieselben). **Nie mehr `app.state` direkt ändern, immer `app:act(name, args)`.**
- **Stage Builder** ändert das Design lokal und schickt es beim Schließen (`app:saveDesign`), der Server rechnet pro Teil-`uid` ab (`Actions.designCost`).
- **Gebäude** `World/Hub.lua` (Server baut es bei x=4000): hell (Tageslicht, Holz, weiß, Farbakzente, kein Neon), Büro mit Laptop + Weltkarten-Tisch + Charts-TV, Mitarbeiter-Tische, Kaffeebar, Empfang, Meetingraum (Seats mit CanTouch!), Lounge, Bühnen-Halle (Rolltor öffnet nach der 1. Show), kleine geschlossene Straße mit Läden, Bushaltestelle, Plakatwand, Tourbus. Z-Fighting-Regel: Deko mind. 0,04 Studs vor der Fläche; Prüfung mit `tools/render3d/scenario_hub.lua` (schreibt `parts.txt`) + `tools/zfight/check.py`.
- **Client-Welt** `Client/World.lua`: Prompts, Namensschilder, goldener Leitpfeil (`GS.objective` bzw. `World.guide(id)`), Weltkarte auf dem Tisch, Pins der Touren, Charts-TV, Artist-Poster, Leute (Mitarbeiter tippen, Passanten, Café-Gäste, mit `People`), Zoom-Grenze 22, Meeting (Kamera auf Tafel, SurfaceGui in PlayerGui, SIGN-Knöpfe, Aufstehen beendet).
- **HUD** (`App:buildHud`): Geld, Datum, Level-Balken, Tempo-Knöpfe (Zeit läuft selbst), Ziel-Zeile, Handy-Knopf (SOCIAL als Smartphone, `Screens/PhoneScreen.lua`), Ladebildschirm `App:showLoading`.
- **Stationen** öffnen Seiten über `app:openStation(station, page)`. `app:go(page)` zu einer Seite einer *anderen* Station schließt und schickt den Pfeil dorthin.
- **Tourplanung** (`PlannerScreen.lua`) in 6 Schritten: Artist (übersprungen bei nur einem) → Land (Karte vollflächig) → Venue (nur Level-erlaubte, Rest grau: `Config.VENUE_LEVEL`) → Datum (Kalender allein) → Ticketpreise → Bestätigen (Bühne automatisch, umschaltbar). „+ ADD ANOTHER SHOW“ zurück zur Karte.
- **Konzerttag**: Jede Show des Tages wird live (`s.skipLive` = auto). Karte „TODAY …“ (`App:showTonight`, Bus fährt nach 8 s), `playShow` auf dem Server, dann `LiveShow.run(walk=true)`: Spieler steht in der Halle, läuft frei, V = laufen, 0–5 = Show-Kameras; danach Ergebnis-Kacheln (`App:showResult`) und zurück ins Büro. Mini-Aufgaben später in `Client/ShowTasks.lua` registrieren (start/update/stop bekommen den Show-Kontext).
- **Freischaltung** (`GS.unlocks`): Büro, Karte, Meeting von Anfang an; Bühnen-Halle nach der 1. Show; Charts nach der 1. fertigen Tour (oder 5 Shows).
- **Sandbox (DEV)** im Hauptmenü nur in Studio / für den Place-Besitzer: Geld 1 Mrd. (wird nach jeder Aktion aufgefüllt), Level 5, alles offen, Knöpfe „SKIP TO NEXT SHOW“ / „+7 DAYS“.
- Tests: `run_mock.py` startet jetzt Server + Client (Attrappe kann RemoteFunction, DataStore, LoadCharacter, Seats `MOCK.sit`, Prompts `MOCK.prompt`). Cheats im Test über `shared.HeadlinerServer.sessions[...]`.
- **Runde 2 (Feedback umgesetzt):**
  - Straße biegt an beiden Enden in eine Kurve (`Hub.STREET`, Ring-Stücke, Seitenstraße), unsichtbare Wand am Kurvenbeginn. Zebrastreifen quer zur Fahrbahn. Läden mit Innenraum (Pizza mit Ofen + rundem Schild, Café, Plattenladen, Musikladen, Bäckerei, Bar, Mode), Balkone, Simse.
  - Verkehr (Client): Autos, Taxis, Stadtbus, Tourbus mit dem Namen der laufenden Tour fahren durch Kurven und Straße (`World.lua` buildTraffic).
  - NPCs: Laufwege in freien Gehweg-Spuren (Test in `tools/render3d/scenario_hub.lua` prüft Kollisionen mit Bäumen/Tischen), Sitzende als eigene Figuren mit Knie (seatedFigure), mehr Looks (Hüte ersetzen Haare, Rucksack, Jacken).
  - Poster zeigen den Artist in 3D (ViewportFrame in SurfaceGui in der PlayerGui), 4 Layouts, Genre-Schriften.
  - **Tourplanung als Weg durch die Räume** (`state.draft` auf dem Server, `GS.planStage`): Meetingraum (PLAN A TOUR auf der Tafel) → Weltkarte (Land, Venue, Datum) → Laptop TOUR PLAN (Ticketpreise) → Bühnen-Halle (Besuch = Bühne geprüft; erste Tour nutzt die Startbühne) → Laptop (Bühne wählen, ANNOUNCE TOUR). Aktionen `setDraft`, `announceTour`.
  - Hallen: `Venue.makeWalkable` macht beim Laufen Wände, Ränge, Barrikaden und Bühnenteile fest (Fans nicht) + unsichtbare Begrenzung. Arena 176×140 (höher), Theater 124×90. Mehr Details: Dach-Traversen, Hauslicht, hängende Line-Arrays, Licht-Traversen, Banner, Bar + Merch, Verfolger (Arena); Rohre, Truss, Discokugel, Poster, Notausgang, Merch (Club); Säulen, Wandlampen, Kassettendecke, Exit-Schilder (Theater). Security-Weste nicht mehr Neon. Scissor-Lift-Geländer mit Pfosten.
- **Runde 3 (Feedback umgesetzt):**
  - Zeit läuft selbst (II / 1x / 2x / 4x, `Config.SPEEDS`), NEXT DAY ist weg. Nur die Opening Night einer Tour fragt „live?“, im Laptop (TOURS) pro Show WATCH/auto. Laptop ohne Sprung-Knöpfe, keine Emojis/Symbole mehr (Roblox zeigt leere Kästchen). Leitpfeil nur im Tutorial (bis zur 1. Show). Bühnen-Halle ab der 1. Tour, „SELECT FOR TOUR“ in My Stages. ~160 neue Social-Posts (`Data/SocialMore.lua`).
  - Stadt: Verkehr in festen Spuren (eine Geschwindigkeit pro Spur, gleiche Abstände), Autos warten vor dem Zebrastreifen, solange jemand quert (`World.crossing`). Passanten gehen von Tür zu Tür (`Hub.DOORS`, `Hub.streetTrip`), verschwinden im Laden und kommen wieder. Der Test prüft alle 92 Wege auf Hindernisse. Pizzeria und Musikladen eingerichtet, Seitenstraßen mit Läden, Fenstern, Bäumen, Laternen, Parkautos. Afro und Dutt aus Blöcken statt Kugeln. Poster schneiden ab (`ClipsDescendants`, keine gedrehten Streifen).
  - **Stage Builder in 2 Schritten:** 1. BUILD (Katalog, Gizmo, Q = platzieren, R/E = drehen), 2. SETLIST & SHOW (Song-Liste links, Artist-Spots nur hier, Instrument-Song, Bildschirm-Inhalte, Effekte pro Song: `rec.songs = {..}` oder `false` = Auto; `LiveShow` FX_HIT). Show-Einstellungen bauen die Bühne nicht neu (kein Springen). Decks ohne versteckte Höhen-Versätze. Gelbe Pfeil-Figur zeigt, wo/wohin der Artist an Instrumenten steht (`Builder.ARTIST_MARK`, in Shows versteckt). Neue Harfe in Menschengröße, neue Teile: Grand Column, Giant Guitar, Velvet Drapes, Barrels, Bookshelf, Lantern Line, Gold Disc Wall. Instrumente mit wechselnden Bewegungen (`People.SEATED/BUSY`, `LiveShow PLAY_MOVES`). PAR Wash mit Lichtkegel, Farbwechsel und Puls. My-Stages-Vorschau mit Halle, Fans und Verlauf.
  - Hallen: Club-Wände bis hinter die Rückwand (keine Ritze), Sitzblöcke enden genau an der Vorhanglinie (`splitAtZ` + Abschneiden in `stands`, Test in `scenario_venue.lua`), echte Ausgänge (Tunnel mit EXIT-Schild in Arena/Stadion, Türen im Theater), Stadion-Rasen ganz mit Bodenplatten bedeckt, Hallen-PARs wechseln die Farbe im Takt.
- **Runde 4 (Feedback umgesetzt):**
  - Reisetage (`GS.travelGap` + `Countries.travelDays`): gleiches Land oder Nachbarland (Landgrenze, Kanaltunnel UK-FR, Öresundbrücke DK-SE; `Countries.NEIGHBOURS`) = am nächsten Tag, gleicher Kontinent = 1 Reisetag, anderer Kontinent = 2 (`Countries.CONTINENT`).
  - Einzelne Shows absagen (`GS.cancelShow`, Aktion `cancelShow`, Knopf CANCEL im Laptop/TOURS): Venue-Miete wird trotzdem bezahlt, Hype sinkt je nach verkauften Tickets, Posts „cancelshow“. Nicht am Show-Tag, nicht die einzige Show. Letzte offene Show abgesagt = Tour fertig (`GS.finishTour`).
  - Bühnen umbenennen: im Builder oben (STAGE NAME) und in My Stages direkt im Namen (Aktion `renameDesign`).
  - Mikro vor dem Mund statt im Kopf, Glitzergürtel (Nova Ray) größer als Torso und Jacke.
  - **Builder:** Größe ziehen = eine Seite wächst, mit Shift beide. Kopie (C) liegt genau auf dem Original (mit einem Pfeil herausziehen = bleibt in Linie). Shift + Klick = Gruppe (`group`, SelectionBox): gemeinsam bewegen, drehen (R / Ring um die Mitte), kopieren, spiegeln, löschen. M spiegelt Auswahl/Gruppe an der Mittellinie x = 0. Seitenmontage `mount = "side"` (Side Wash, Side Beam, Side Blinder, Side Strobe, Hanging Speakers): rastet am nächsten Truss Tower ein (`Stage3D.snapToTower`), Höhe mit Lift up / grünem Pfeil.
  - **Band-Tab** (Kategorie „Band“): Drummer, Gitarrist, Bassist, Keyboarder, Backing Singer spielen die ganze Show an ihrem Platz (`LiveShow` BAND_ITEMS); Artist-Instrumente bleiben für den Artist.
  - Kabuki-Vorhang: Farbe (`rec.cc`) beim Bauen, in Schritt 2 Animation (`rec.anim` drop / rise / split) und Song, in dem er öffnet (`rec.cs`, `ctx.songStart`).
  - Lift im letzten Song = Exit-Lift: Artist geht im Finale drauf, winkt am Ende und fährt runter (`finaleLift`).
- **Offen / Feedback abwarten:** alles aus Runde 4 im echten Roblox, Mini-Aufgaben in der Show.

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
  Client/Screens/        Office (Zentrale), Planner (Tourplanung in 5 Schritten), Artists, Tours, Charts
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
  - **Hall of the Stadium** (Zürich-Oerlikon, Hallenstadion: Halle von 1939, Umbau 2004–05, ~13.000 bei Konzerten, max. 15.000): Kasten mit Rundenden, Glasfoyer, Tramhaltestelle mit blauen Trams, Messehallen, Schweizer Fahnen, Hügel. Flug: die Wallisellenstraße entlang zur Halle.
  - **Stadium of France** (Saint-Denis, Stade de France: ~80.000, „schwebendes“ elliptisches Dach auf 18 Masten): Kanal mit Schiff und Fußgängerbrücke, Esplanade, Treppentürme, A1 im Graben, RER, Eiffelturm in der Ferne; durch die Dachöffnung sieht man Bühne, Ränge und Handylichter.
  - **Bernabeo Stadium** (Madrid, Santiago Bernabéu nach dem Umbau: Stahllamellen-Fassade, Schiebedach, 360°-Screen): Paseo de la Castellana mit Baum-Mittelstreifen, Metro-Eingang, Eck-Rampentürme, Bürotürme; Dach heute offen.
  - **Wemblee Stadium** (London, Wembley: 90.000, Bogen 133 m hoch / 315 m Spannweite): Wembley Way voller Fans vom Bahnhof bis zur Statue, Arena nebenan, rote Busse, Züge.
  - **Seit Nov 2026 echte Umgebung aus OpenStreetMap** (`Data/MenuCity/<name>.lua`, erzeugt mit `tools/osm/fetch_tiles.py` + `tools/osm/build_city.py` aus OpenFreeMap-Vektorkacheln, ODbL, Hinweis in den Credits): jedes Gebäude mit echter Höhe (als 1–8 gedrehte Quader), Straßen, Bahn/Tram, Brücken, Wasser, Parks, Plätze. Die Venue-Modelle stehen auf ihrem echten Grundriss (`X` im Datenmodul, `venueFrame`), Dom/Empire State auf ihren Ankern. Fans, Lampen, Bäume usw. werden nur auf freien Flächen gesetzt (`freeAt`), Gebäude unter der Flugbahn werden gekappt. Glas-Eingänge haben eine undurchsichtige, beleuchtete Lobby dahinter. Vorschau der Daten: `tools/osm/preview.py <name> out.png`.
  - Szenen laufen in **zufälliger Reihenfolge** (jede einmal pro Runde, nie zweimal hintereinander; `MenuScene.forceOrder` für die Render-Tests). Köln startet jetzt mit dem angestrahlten Dom groß im Bild (Blick von Deutz über den Rhein), O3: Halbinsel rundum bebaut + Skyline in allen Richtungen (keine leere Fläche mehr). Fans im Menü: Beine, Körper, Kopf (Head-Mesh), Haare.
  - Technik: Gebäude-Baukasten mit LOD nach Abstand zur Flugbahn, Höhen werden automatisch unter der Flugbahn gekappt (keine Kollision), Budgets für Lichter/SurfaceGuis, ~4k/12k/6k Parts. Suchscheinwerfer, blinkende Flugwarnlichter, wechselnde LED-Texte, Bloom.
- **Neues Spiel:** Label benennen, einen von 3 Start-Artists wählen. **Büro** als Zentrale mit Kacheln, nächsten Shows und News.
- **Fortschritt:** 5 Label-Level nach verkauften Tickets. Größere Artists erst ab höherem Level.
- **Tourplanung (5 Schritte, aktueller Stand siehe weiter unten):** Artist → Termine (Kartenfenster + Hallenliste + Monatskalender) → Bühne pro Hallengröße → Ticketpreise pro Bereich → Bestätigen.
- **Simulation:** Nachfrage pro Land (Fans, Hype, Genre-Vorlieben, Preis), versteckte ±25 % Abweichung, Vorverkauf über Zeit, Marketing, Kosten (Miete, Produktion 8 % des Equipmentwerts, Reisen, 35 % Artist-Anteil), Bewertungen, Fanwachstum, Achievements, Charts.
- **Stage Builder (neu, Stil wie Theme Park Tycoon 2):** Katalog unten (Kategorien Stage / Artist / Lights / Screens / Effects / Set Pieces, Karten mit 3D-Bild + Preis), Werkzeugleiste darüber (Grid, Dreh-Raster 15/45/90°, Drehen, Kopieren, Löschen, ✕, ✓ PLACE). Ablauf: Karte wählen → in die Welt klicken → Teil steht „noch nicht gekauft“ (grün) → mit Gizmo ausrichten (rot X, blau Z, grün Höhe = `rec.yo`, oranger Ring drehen, goldene Würfel Größe) → ✓ kauft. Inspector rechts nur bei Auswahl. Preis am Mauszeiger. „?“ zeigt die Steuerung.
- **MY STAGES (Bibliothek, `Screens/StagesScreen.lua`):** Karten mit 3D-Vorschau, Songs/Items/Kosten, ON TOUR/STARTER, Edit/Copy/Delete. Dialog „New stage“: Größe, Typ, Start (leer, Basis-Deck oder Vorlage).
- **Vorlagen aus echten Touren** (`StageItems.PRESETS`, `shop = true` kostet): The Cube (in-the-round, LED-Würfel, 8 LED-Türme, Armbänder – angelehnt an Billie Eilish HMHAS / Metallica M72), Portal Ring (Portal + Roboterarme – angelehnt an Beyoncé Renaissance), Runway & Moon (Skyline, Laufsteg, Mond, Statue – angelehnt an The Weeknd).
- **Setlist = Anzahl Artist-Spots** (3–12, ohne Spots 4). Spot n = Song n, Reihenfolge im Inspector („Earlier/Later“). Lift/Piano/Keys/Drums/DJ „in Song n“. Screens: Inhalt für die ganze Show + Änderungen pro Song.
- **Live-Kamera auf Screens** (`Client/LiveFeed.lua`): eigene 3D-Szene im ViewportFrame: Artist (Kopien der Figuren, Kamera kreist) oder Fans (Crowd mit Armen, Lightsticks, Handys, Kamera schwenkt). **Wichtig:** Roblox zeichnet ViewportFrames nicht in SurfaceGuis im Workspace. Darum liegen die Screen-SurfaceGuis in der PlayerGui mit `Adornee` = Screen-Part (`Builder.surfaceText(..., adorn=true)`), werden über `Destroying`/`AncestryChanged` mit dem Part entfernt. Vorschaubilder (`preview = true`) nutzen normale SurfaceGuis.
- **Setlist-Plan** (`GS.songPlan`): Lifts/Instrumente behalten ihre Songnummer, Artist-Spots nehmen die freien Nummern in Platzier-Reihenfolge. Song 1 = Opener, Song 4 der Setlist = Ballade, Song 8 = großer Hit (Finale).
- **Laufen statt Teleportieren:** Wegfindung toleriert kleine Lücken und Stufen bis 4,2; ohne Weg läuft der Artist gerade hinüber (nie mehr „hidden“).
- **Sound** (`Client/SoundFX.lua`, `Data/Audio.lua` = Asset-IDs, `Data/AudioMap.lua` = Zeitbereiche, generiert): Menü-/Büromusik, Klick-/Hover-Sounds an allen Buttons, Sold-out/Level-up/Kasse, in der Show Crowd-Loop, Jubel, Applaus, Pyro-/CO2-/Feuerwerk-Sounds und pro Song der passende 30-s-Ausschnitt aus der Artist-Datei (PlaybackRegion). „▶ Listen“ an Artist-Karten. Ohne IDs ist alles still.
- **Musik-Generator** `tools/music/make_audio.py` (+ `synth.py`): eigene Synth-Instrumente (Drums, Bass, Piano, Rhodes, Gitarren per Karplus-Strong/Verzerrung, Supersaw, Pads, Formant-„Stimme“), Stil pro Artist (Tempo, Tonart, Akkordfolgen, Drum-Pattern, Instrumente). Ausgabe in `audio/` (14 .ogg). Upload-Anleitung: `audio/README.md`.
- **Tageslänge:** Geschwindigkeiten 15 s / 4 s / 1 s pro Tag, Fortschrittsbalken unter dem Datum.
- **Social-Fotos** sind kleine 3D-Szenen, 13 Motive (`SocialScreen.photo`, `Data/Social.PHOTOS` = Chance + Motive pro Post-Art): Bühne aus der Crowd, Selfie, Oberrang-Weitwinkel mit Handylichtern, Nahaufnahme mit Spot, Konfetti, Pyro-Flammen, Handylichter, Barrikade/erste Reihe, Schlange vor der Halle, Fan-Schild, Merch-Flatlay; Ticket und Tourplakat als 2D-Bild. Rund 90 zusätzliche Post-Texte.
- **Kleine Props / Decor:** Guitar Stand, Monitor Wedge, Percussion, Bar Stool, Chair, Floor Uplight, LED Bar, Light Pole, String Lights, Paper Lanterns, Retro TV Stack, Neon Heart/Star/Lightning, Bubble Machine, Snow Machine, Wind Machine, Sofa, Rug, Floor Lamp, Side Table, Candles, Potted Plant, Tree, Park Bench, Street Lamp, Road Cases, Balloon Arch, Logo Banner (Kategorie „Decor“).
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
- **Runde 2 (Nov 2026):** Weltkarte ohne Datumsgrenzen-Streifen (Fidschi/Russland werden geteilt), Karte nutzt die volle Höhe, Venue-Liste klappt nur bei gewähltem Land auf (✕ schließt), Nachbarländer leicht unterschiedlich getönt. Hallen: Arena-Wand bis zum Dach, Theater mit getrennten Balkon-Ebenen (keine Überschneidungen), Stadion-Screens auf Gerüst unter dem Dach, Fans mindestens 2,6 Studs hinter Gittern, **Stadt rund um jede Halle** (`Venue.city`: Ringstraße, Parkplätze, Häuserreihen, auch im Builder). **Z-Fighting** systematisch beseitigt (`tools/zfight/scenario_parts.lua` + `check.py` finden deckungsgleiche Flächen; überlappende Decks bekommen minimal unterschiedliche Höhen). **Alle alten Modelle überarbeitet** (Lichter mit runden Köpfen/Displays/Bügeln, Followspot auf Stativ, Disco-Kugel mit Motor, Statue, Roboterarm mit Gelenken, Haus, Skyline, Blumen, Möbel, Lampen, Bäume, Amps, Percussion, TVs, Scherenlift mit Scherenarmen …) und 17 neue Teile: Acoustic Set + Concert Harp (spielbar wie Piano), Double Bass, String Section, Horn Section, Choir Risers, Vintage Car, Chopper Bike, Royal Throne, Giant Hand, Stage Swing, Ferris Wheel, Retro Rocket, Stage Fountain, Lighthouse, Floating Cloud, Rainbow Arch. Render-Kontrolle aller Teile: `tools/render3d/scenario_catalog.lua`.
- **Runde 3 (Nov 2026):**
  - **Tourplaner in 5 Schritten** (`PlannerScreen.lua`): 1 Artist → 2 Termine (links oben kleines Weltkarten-Fenster (`mapView`, 760×500, Rest der 3D-Karte per `mapMask` abgedeckt; Zoomstufen ×1.7, `maxDist` 1000), darunter Hallenliste des Landes mit **PICK**; rechts **Monatskalender** (`refreshRoutePanel`): mit gewählter Halle zeigt jeder Tag frei/belegt/Reisetag (`dayState`), Klick auf freien Tag bucht (`dayClicked`), Klick auf eigene Show entfernt sie, Shows anderer Touren grau im Tag; unten Terminleiste + Farblegende; belegte Tage durch andere Events (`GS.venueBusy`, deterministisch, Stadien öfter) und durch eigene Shows anderer Artists; Reisezeit `GS.travelGap`) → 3 Bühne (Produktion pro Hallengröße, EDIT/NEU) → 4 **Tickets wie im Ticketshop**: Saalplan von oben, Preis pro Bereich (`Sim.SECTIONS`: Club nur Stehplatz; Theater Parkett/1. Rang/2. Rang; Arena/Stadion Golden Circle, Innenraum, Unter-/Oberrang; Amphi Pit/Sitzplätze/Rasen), Prognose pro Bereich → 5 Bestätigen.
  - **Verkauf pro Bereich** (`Sim.splitSections`): günstige Bereiche verkaufen schneller, ausverkaufte schicken Fans zu den anderen. Shows speichern `prices`, `secSold`; `price` = Durchschnitt. Preisänderung auf dem Tours-Screen skaliert alle Bereiche.
  - **Tour-Abrechnung** (`App:tourReport`): nach der letzten Show und per Button TOUR REPORT; echte Zahlen pro Show (Ticket-Einnahmen, Miete, Produktion, Reise, Artist-Anteil, Gewinn), Diagramme „Geld pro Show“, „Wohin das Geld ging“, „Auslastung pro Show“, beste/schwächste Show.
  - Hallen: kein Fan mehr neben der Hauptbühne (Vorderkante der Hauptbühne aus dem Bühnen-Raster), Security in Warnweste/Kappe und seltener, verhüllte Plätze hinter der Bühne schwarz, Club mit Ziegelwand/Samtvorhang/Neon hinter der Bühne.
  - Sitzen (Piano, Drums, Akustik, Harfe): Oberschenkel nach vorne, Füße am Boden. Pop-Up-Lift: eigene Flug-Pose.
  - Live-Fan-Screens: Schnitte zwischen Schwenk, Fans mit Handylichtern, Tanzenden, Verkleideten, Schild, Freunden Arm in Arm.
  - **Traversen platzieren:** Rig-Teile hängen genau unter dem Mauszeiger (Schnitt mit der Rig-Ebene statt mit dem Boden), neue Traversen richten sich parallel/rechtwinklig zur nächsten aus und schließen bündig an (`Stage3D.alignTruss`), Lichter rasten auf 1-Stud-Raster ein.
  - Menü-Szenen: freie Plätze vor den Eingängen (`clear` in `build_city.py`), schwebende OSM-Teile weggelassen, Gebäude/Fensterbänder/Flächen mit Mini-Versatz gegen Z-Fighting. Hauptmenü klebt auch auf Breitbild-Monitoren am linken Rand (`app.sideGap`).
- **Hallen-Innenräume neu (Nov 2026, `Venue.lua`):** Arena = ovale Schüssel mit Unter- und Oberrang, Blöcken mit Treppen, Umlauf mit EXIT-Schildern, Logen, LED-Band, Dach mit Laufstegen und Videowürfel. End Stage: die Schüssel läuft hinter der Bühne weiter, die Plätze dort und daneben bleiben leer und sind mit schwarzen Vorhängen abgehängt. Center Stage: volle Runde. Stadion = Fußballstadion mit Rasen, Bodenschutz, zwei Rängen rundum, Dach mit Flutlicht, Eck-Screens. Theater mit Balkonen, Logen, Vorhang und Kronleuchtern; Amphitheater mit Muschel. **Absperrgitter** folgen automatisch der Bühnenform (Fotograben 8 Studs, Security in Gelb), FOH-Pult mit Gitter. Fans: Beine, Shirt, Kopf mit Head-Mesh, Haare/Cap, manche mit erhobenem Arm.
- **Stadionbühnen:** Klasse Stadium jetzt x ±120, z −70..200, Rig 75, 340 Teile; Decks bis 160×120, LED-Wand bis 200×70, Truss bis 240. Neu: **Stadium Structure** (Gerüst-Türme mit PA, Dach, Flügel), **Delay Tower** (Turm im Publikum), Vorlage **Stadium Tour**.
- **Lifts:** Artist Lift mit **Falltür** (zwei Klappen klappen nach unten, dann fährt die Plattform hoch). Neu: **Pop-Up Lift** (schießt den Artist mit Funken und CO2 hoch, Sprung und Landung) und **Tower Lift** (runde B-Stage auf Teleskopsäule, hebt den Artist während seines Songs ~26 Studs hoch, angelehnt an Billie Eilish HMHAS). Tower ohne feste Songnummer nimmt wie ein Spot die nächste freie Nummer (`GS.songPlan`, `GS.LIFT_ITEMS`).
- **Effekte realistischer:** Partikel-Texturen von Roblox (fire/smoke/sparkles), Flammenprojektor mit Feuersäule und schwarzem Rauch, Kaltfunken-Fontäne mit Funkenstreifen, CO2-Jet mit Flasche und Düse. **Instrumente:** Flügel mit echter Flügelform, offenem Deckel, Tasten und Pedalen; Schlagzeug mit runden Kesseln, Spannreifen, Böckchen, Becken mit Kuppe, Stative; Keyboard-Rig mit Tasten/Reglern; Gitarre mit Korpus-Rundungen (auch in der Hand der Band). Rohre (`tube`) sind jetzt echte Zylinder.
- **Pit Barrier** ist versteckt (`def.hidden`), alte Bühnen damit funktionieren weiter. Artist-Vorschaubilder: Pose ohne Hand vor dem Gesicht.
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

## 4b. Arbeitsablauf (so wurde bisher geliefert)
- Arbeits-Branch: `claude/clever-goldberg-ehd8ui` (normal pushen, nie force-push). Neuer Chat: diesen Branch auschecken und darauf weiterarbeiten.
- Jede Lieferung: `check.py`, `test_logic.py`, `run_mock.py` → `build.py` → Commit + Push → `Headliner.rbxlx` dem User schicken, mit kurzer deutscher Zusammenfassung.
- Neue Planner-Abläufe immer auch in `tools/scenario_full.lua` und `tools/scenario_screens.lua` nachziehen und die Screens per `tools/screens.py` ansehen.
- `api-dump.json` / `api_classes.lua` liegen nicht im Repo: in einem neuen Chat zuerst wie oben neu erzeugen.
- Letzter Stand (Nov 2026): Terminplanung neu (Kartenfenster links oben, Hallenliste mit PICK darunter, großer Monatskalender rechts). **Feedback des Users dazu abwarten**, v. a. Kartenzoom im kleinen Fenster im echten Roblox.

## 5. Offenes Feedback und nächste Schritte (Priorität von oben)
0. **Großer Umbau Nov 2026 (Hallen, Stadionbühnen, Lifts, Effekte, Instrumente, Social-Fotos, 4 neue Menü-Szenen): Feedback abwarten.** Echte 3D-Meshes wurden bewusst nicht genutzt (die .rbxlx wird jedes Mal neu gebaut, Meshes müssten hochgeladen und per ID eingebunden werden). Möglich später: `build.py` bettet MeshParts mit Asset-IDs ein, die der User hochlädt.
1. **Hauptmenü-Venues: neu gebaut (Stadtviertel + Kamerafahrt), Feedback des Users abwarten.** Mögliche nächste Schritte: Performance auf schwachen PCs prüfen (Manhattan ~12k Parts, Aufbau während der Schwarzblende), ggf. Detail an „Crowd detail“-Setting koppeln; weitere Venues; echte Meshes (OBJ/FBX) für noch feinere Fassaden.
2. **Feedback des Users zum neuen Stage Builder, Social-Tab, Live-Screens und Looks abwarten** (großer Umbau, Nov 2026).
3. **Büro mit Roblox-Charakter**, der sich an den PC setzt. Das Label-Menü läuft „im PC“.
4. **Neue Songs (Nov 2026, mehr Abwechslung):** 12 Artist-Dateien + `menu.ogg` neu erzeugt (Song-Typen pro Setlist-Nummer, Songform Strophe/Pre/Refrain, lange Menümusik 3:30 + Büro 2:30). Neu hochgeladen und eingetragen (sfx.ogg ist noch die erste Version). Wichtig für später: Wenn sich die Länge von menu.ogg ändert, müssen Datei-ID und MENU-Zeile in `Data/AudioMap.lua` gleichzeitig wechseln.
5. **Audio-IDs eintragen:** User lädt die 14 Dateien aus `audio/` hoch und schickt die IDs → in `Data/Audio.lua` eintragen, neu bauen. Danach Lautstärken/Mix im echten Spiel abhören und ggf. im Generator nachjustieren.
5. Balancing beobachten: User hat bisher alles ausverkauft (Clubs). Leere bei schwachem Verkauf funktioniert (Crowd = verkaufte Tickets), wurde aber noch nicht gesehen.

## 6. Bekannte Grenzen
- Speichern geht nur, wenn der Place veröffentlicht ist (DataStore).
- Musik fehlt noch, weil Roblox-Audio hochgeladen werden muss.
- Die Live-Kamera auf Screens funktioniert nur während Show/Vorschau.
