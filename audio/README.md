# Sound für HEADLINER

Alle Dateien hier wurden mit `tools/music/make_audio.py` erzeugt (eigener Synthesizer, keine fremden Samples).

| Datei | Inhalt |
|---|---|
| `menu.ogg` | Titelmusik (Hauptmenü) + Büro-Musik |
| `sfx.ogg` | Klick, Hover, Kasse, Sold out, Level-up, Jubel, Applaus, Crowd, Pyro, CO2, Feuerwerk … |
| `lila.ogg` … `nova.ogg` | je 12 Songs × 30 s für jeden Artist (Song 4 = Ballade, Song 8 = großer Hit) |

## So kommen die Sounds ins Spiel (einmalig, ca. 10 Minuten)

1. **create.roblox.com** öffnen → oben **Creations** → links **Development Items** → **Audio** → **Import Asset** (oder: in Roblox Studio *View → Asset Manager → Bulk Import*).
2. Alle **14 .ogg-Dateien** hochladen. (Limit: 100 Audio-Uploads pro Monat ohne ID-Verifizierung, jede Datei unter 7 Minuten. Das passt.)
3. Nach der Prüfung durch Roblox bei jeder Datei die **Asset-ID** kopieren (Rechtsklick → *Copy Asset ID*).
4. Die 14 IDs an Claude schicken, z. B. so:
   ```
   menu 123456789
   sfx 123456790
   lila 123456791
   ...
   ```
   Claude trägt sie in `src/Headliner/Data/Audio.lua` ein und baut eine neue `Headliner.rbxlx`.
5. Wichtig: Die Audios müssen für dein Spiel freigegeben sein. Wenn du sie mit demselben Account hochlädst, dem auch das Spiel gehört, passiert das automatisch.

Solange keine IDs eingetragen sind, ist das Spiel einfach still (keine Fehler).
