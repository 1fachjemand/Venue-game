# Downloads OpenMapTiles vector tiles (OpenFreeMap, data (c) OpenStreetMap contributors, ODbL) around a point.
# usage: python3 tools/osm/fetch_tiles.py <cache dir> <lat> <lon> <half size in m> [zoom=14]
import sys, os, math, json, time, urllib.request
cache, lat, lon, half = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
z = int(sys.argv[5]) if len(sys.argv) > 5 else 14
os.makedirs(cache, exist_ok=True)
meta_path = os.path.join(cache, "tilejson.json")
if not os.path.exists(meta_path):
    req = urllib.request.Request("https://tiles.openfreemap.org/planet", headers={"User-Agent": "venue-game-dev"})
    open(meta_path, "wb").write(urllib.request.urlopen(req, timeout=30).read())
tpl = json.load(open(meta_path))["tiles"][0]
def tile(lat, lon):
    n = 2 ** z
    x = (lon + 180) / 360 * n
    y = (1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi) / 2 * n
    return int(x), int(y)
dlat = half / 110540
dlon = half / (111320 * math.cos(math.radians(lat)))
x0, y0 = tile(lat + dlat, lon - dlon)
x1, y1 = tile(lat - dlat, lon + dlon)
n = 0
for x in range(x0, x1 + 1):
    for y in range(y0, y1 + 1):
        p = os.path.join(cache, f"{z}_{x}_{y}.pbf")
        if os.path.exists(p):
            continue
        url = tpl.replace("{z}", str(z)).replace("{x}", str(x)).replace("{y}", str(y))
        req = urllib.request.Request(url, headers={"User-Agent": "venue-game-dev"})
        open(p, "wb").write(urllib.request.urlopen(req, timeout=60).read())
        n += 1
        time.sleep(0.3)
print("tiles", x0, x1, y0, y1, "downloaded", n)
