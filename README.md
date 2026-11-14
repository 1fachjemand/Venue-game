# HEADLINER – Music Label Tour Manager (Roblox)

**Spielen:** `Headliner.rbxlx` in Roblox Studio öffnen (Datei → Öffnen) und auf **Play** drücken.

## Projektaufbau
- `src/Headliner/Data` – Länder & Venues (Kapazitäten nach Wikipedia, Stand Nov. 2026), Artists, Bühnenteile, Rivalen-Touren, Achievements
- `src/Headliner/Logic` – Spiellogik (Nachfrage, Ticketverkauf, Bewertungen, Finanzen); reines Lua, ohne Roblox testbar
- `src/Headliner/Client` – Oberfläche, Weltkarte, Stage Designer, 3D-Live-Show
- `src/server` – Speichern (DataStore, funktioniert nur in einem veröffentlichten Place)
- `tools/` – Build und Tests

## Bauen & testen
```bash
python3 tools/build.py                               # erzeugt Headliner.rbxlx
python3 tools/test_logic.py                          # Logik-Tests (benötigt: pip install lupa)
python3 tools/check.py <API-Dump.json>               # Syntax-, Variablen- und Roblox-API-Prüfung
python3 tools/run_mock.py <api_classes.lua> tools/scenario_full.lua   # automatisches Durchspielen
```
