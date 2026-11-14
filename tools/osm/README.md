# Echte Umgebung für die Hauptmenü-Szenen
Kartendaten: (c) OpenStreetMap contributors, ODbL – geladen als Vektorkacheln von OpenFreeMap (OpenMapTiles-Schema).
```bash
python3 tools/osm/fetch_tiles.py <cache> <lat> <lon> <halbe Größe in m>   # lädt die z14-Kacheln (einmalig)
python3 tools/osm/build_city.py <cache> <name>                           # -> src/Headliner/Data/MenuCity/<name>.lua
python3 tools/osm/preview.py <name> out.png [halbe Größe in Studs]         # Draufsicht zum Prüfen (Raster in Studs)
```
Szenen-Einstellungen (Mittelpunkt, Drehung, ersetzte Gebäude, Anker) stehen oben in `build_city.py`.
Benötigt: `pip install mapbox-vector-tile shapely pillow`.
