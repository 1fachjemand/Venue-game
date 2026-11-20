# Bilder für die Spielseite (Thumbnail + Icon) im 3D-Roblox-Stil
Die Bilder entstehen aus einer echten Show des Spiels: `scenario_keyart.lua` baut eine große Rockbühne
(LED-Wand, Seiten-Screens, Moving Heads, Laser, Halo, Pyro, Konfetti), lässt "The Rusty Wires" in der Arena
spielen und speichert ab Sekunde 70 alle 2 s die Szene als JSON (Teile, Lichtkegel, Lampen).
`keyart.html` zeichnet das mit three.js (Licht, Dunst, Glow, runde "Plastik"-Figuren, 3D-Schriftzug).

```bash
S=<scratch>; mkdir -p $S/ka
OUT_DIR=$S/ka python3 tools/run_mock.py api_classes.lua tools/keyart/scenario_keyart.lua   # -> keyart_rock_N.json
(cd $S/ka && npm pack three@0.160.0 && tar xzf three-0.160.0.tgz && mv package three)
cp /usr/share/fonts/opentype/inter/InterDisplay-Black.otf tools/keyart/keyart.html $S/ka/
L="amb=0.75&exp=1.0&thr=0.9&scrb=1.0&nowhite=1&spot=0.4&keys=0,30,60,0,14,0,255,225,200,300,12,1"
node tools/keyart/shoot.js $S/ka "f=keyart_rock_6.json&$L&cam=0,6.5,80&look=0,19,-4&fov=38&ts=30&tpos=0,66,0&tx=0.22&sub=CONCERT TOUR TYCOON&suby=29&subs=34" art/headliner_thumbnail.png 1920 1080
node tools/keyart/shoot.js $S/ka "f=keyart_rock_9.json&$L&cam=0,6.5,80&look=0,19,-4&fov=38&ts=30&tpos=0,66,0&tx=0.22&sub=CONCERT TOUR TYCOON&suby=29&subs=34" art/headliner_thumbnail_2.png 1920 1080
node tools/keyart/shoot.js $S/ka "f=keyart_rock_9.json&$L&cam=0,10,36&look=0,16,2&fov=40&ts=21&tpos=0,-74,0&tx=0.15" art/headliner_icon.png 1024 1024
```
Wichtige URL-Werte: `cam`/`look`/`fov` (Kamera), `title=0` (ohne Schrift), `text`, `ts` (Schriftgröße), `tpos`,
`sub`/`suby`/`subs` (Untertitel), `nowhite=1` (weiße Blinder-Kegel weglassen), `spot` (Lampenstärke), `keys`
(Zusatzlichter: x,y,z,Ziel x,y,z,r,g,b,Stärke,Winkel,Schatten), `band` (Name auf der LED-Wand), `scr` (LED-Farben).
`shoot.js` liefert die Dateien direkt von der Platte aus (kein Webserver nötig).
