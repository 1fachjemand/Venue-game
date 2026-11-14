# Vorschau der Hauptmenü-Szenen, Hallen und Bühnenteile ohne Roblox
Grobe 3D-Vorschau (three.js, ohne SurfaceGui-Texte, ohne Bloom) zum Prüfen von Komposition und Kamerafahrt.
```bash
D=/tmp/menu_render; mkdir -p $D
OUT_DIR=$D python3 tools/run_mock.py api_classes.lua tools/render3d/scenario_export.lua   # -> sceneN.json
(cd $D && npm pack three@0.160.0 && tar xzf three-0.160.0.tgz && cp package/build/three.min.js .)
for k in 1 2 3; do (printf 'window.SCENE='; cat $D/scene$k.json; printf ';') > $D/scene$k.js; done
cp tools/render3d/view.html $D/ && node tools/render3d/shoot.js $D 1,2,3 0,3,5,6        # -> shot_S_C.png
```
Kamera-Index c: 0 = 1 s, danach alle 6 s (1, 7, 13, ... 43 s).
Weitere Exporte (gleiche Anzeige mit view.html):
- `scenario_export.lua`: alle 7 Menü-Szenen (feste Reihenfolge über `MenuScene.forceOrder`)
- `scenario_venue.lua`: Hallen-Innenräume mit Crowd (Arena End/Center, Stadion, Theater, Club, Amphi), 4 Kameras
- `scenario_items.lua`: Instrumente, Lifts (halb ausgefahren), Effekte, Stadion-Teile in Nahaufnahme
