# Generates src/Headliner/Data/WorldMap2D.lua: a flat top-down world map for the tour planner (Map2D.lua).
# Source: Natural Earth country borders (world-atlas 2.0.2, countries-50m.json, public domain).
#   python3 tools/gen_map2d.py path/to/countries-50m.json
# Equirectangular, RES cells per degree, latitude TOP..BOT. Only the continents and the big islands are kept
# (small islands are left out); the playable countries keep every larger part, Singapore at least one cell.
# Every country is one colour layer: playable ones by id, the others in 4 neutral tones (neighbours differ).
import json, sys
from shapely.geometry import Polygon, MultiPolygon, box
from shapely.affinity import translate
from shapely.strtree import STRtree
from PIL import Image, ImageDraw

RES, TOP, BOT, LON0, LON1 = 4, 76.0, -56.0, -170.0, 190.0
W, H = int((LON1 - LON0) * RES), int((TOP - BOT) * RES)
MIN_OTHER, MIN_PLAY = 4.0, 0.35  # smallest kept part (square degrees)

topo = json.load(open(sys.argv[1]))
sx, sy = topo["transform"]["scale"]; tx, ty = topo["transform"]["translate"]
arcs = []
for arc in topo["arcs"]:
    x = y = 0; pts = []
    for dx, dy in arc:
        x += dx; y += dy; pts.append((x * sx + tx, y * sy + ty))
    arcs.append(pts)
def ring(idx):
    pts = []
    for i in idx:
        a = arcs[i] if i >= 0 else arcs[~i][::-1]
        pts.extend(a if not pts else a[1:])
    if any(abs(pts[k][0] - pts[k - 1][0]) > 180 for k in range(1, len(pts))):
        pts = [(x + 360 if x < 0 else x, y) for x, y in pts]
    return pts
def parts_of(g):
    polys = []
    arcsets = [g["arcs"]] if g["type"] == "Polygon" else (g["arcs"] if g["type"] == "MultiPolygon" else [])
    for p in arcsets:
        q = Polygon(ring(p[0]), [ring(r) for r in p[1:]]).buffer(0)
        # the map runs from 170W to 190E: shift the far west of Russia / Alaska tip into view
        for piece in ([q] if q.geom_type == "Polygon" else list(q.geoms)):
            if piece.bounds[2] < LON0:
                piece = translate(piece, 360)
            polys.append(piece)
    return polys

IDS = {"826": "uk", "372": "ie", "250": "fr", "528": "nl", "276": "de", "756": "ch", "380": "it", "724": "es", "752": "se",
       "840": "us", "124": "ca", "484": "mx", "076": "br", "032": "ar", "392": "jp", "410": "kr", "036": "au", "784": "ae", "710": "za", "056": "be", "040": "at", "616": "pl", "578": "no", "208": "dk", "620": "pt", "203": "cz", "152": "cl", "170": "co", "356": "in", "608": "ph", "702": "sg", "764": "th", "554": "nz"}
countries = []  # { key, cid or None, parts }
byCid = {}
for k, g in enumerate(topo["objects"]["countries"]["geometries"]):
    parts = parts_of(g)
    if not parts:
        continue
    cid = IDS.get(str(g.get("id", "")).zfill(3))
    big = max(parts, key=lambda p: p.area)
    keep, far = [], []
    for p in parts:
        if p.bounds[1] > TOP or p.bounds[3] < BOT:
            continue
        if cid:
            # far away parts (French Guiana, Hawaii, Canary Islands...) are not the touring country:
            # big ones stay as neutral land, small ones are left out
            if p is not big and p.distance(big) > 12 and p.area < 50:
                if p.area >= MIN_OTHER:
                    far.append(p)
            elif p.area >= MIN_PLAY or p is big:
                keep.append(p)
        elif p.area >= MIN_OTHER:
            keep.append(p)
    if keep and cid and cid in byCid:
        e = byCid[cid]
        e["parts"] = e["parts"] + keep
        e["geom"] = MultiPolygon(e["parts"]).buffer(0.05)
    elif keep:
        countries.append({"key": k, "cid": cid, "parts": keep, "geom": MultiPolygon(keep).buffer(0.05)})
        if cid:
            byCid[cid] = countries[-1]
    if far:
        countries.append({"key": k, "cid": None, "parts": far, "geom": MultiPolygon(far).buffer(0.05)})

# neutral tones for the other countries: neighbours get different tones (greedy colouring)
others = [c for c in countries if not c["cid"]]
tree = STRtree([c["geom"] for c in others])
for i, c in enumerate(others):
    used = set()
    for j in tree.query(c["geom"]):
        j = int(j)
        if j != i and "tone" in others[j] and others[j]["geom"].intersects(c["geom"]):
            used.add(others[j]["tone"])
    c["tone"] = next(t for t in range(1, 9) if t not in used)
    if c["tone"] > 4:
        c["tone"] = (i % 4) + 1

# the playable countries: 3 light tones, neighbours differ (so borders show)
plays = [c for c in countries if c["cid"]]
ptree = STRtree([c["geom"] for c in plays])
for i, c in enumerate(plays):
    used = set()
    for j in ptree.query(c["geom"].buffer(0.3)):
        j = int(j)
        if j != i and "tone" in plays[j] and plays[j]["geom"].buffer(0.3).intersects(c["geom"]):
            used.add(plays[j]["tone"])
    c["tone"] = next((t for t in range(1, 4) if t not in used), 1)

# raster: one index per cell
img = Image.new("I", (W, H), 0)
draw = ImageDraw.Draw(img)
def px(pt):
    return ((pt[0] - LON0) * RES, (TOP - pt[1]) * RES)
for idx, c in enumerate(countries, start=1):
    c["idx"] = idx
    for p in c["parts"]:
        draw.polygon([px(q) for q in p.exterior.coords], fill=idx)
    for p in c["parts"]:
        for hole in p.interiors:
            draw.polygon([px(q) for q in hole.coords], fill=0)
pix = img.load()
for c in countries:
    if c["cid"]:
        big = max(c["parts"], key=lambda p: p.area)
        pt = big.representative_point()
        x, y = px((pt.x, pt.y))
        if not any(pix[i, j] == c["idx"] for j in range(H) for i in range(max(0, int(x) - 3), min(W, int(x) + 4)) if abs(j - y) < 4):
            pix[int(x), int(y)] = c["idx"]

def rects(idx):
    runs = {}
    for j in range(H):
        i = 0
        while i < W:
            if pix[i, j] == idx:
                s = i
                while i < W and pix[i, j] == idx:
                    i += 1
                runs.setdefault(j, []).append((s, i - s))
            else:
                i += 1
    open_, out = {}, []
    for j in sorted(runs):
        nxt = {}
        for c0, l in runs[j]:
            if (c0, l) in open_ and open_[(c0, l)][0] + open_[(c0, l)][3] == j:
                r = open_.pop((c0, l)); r[3] += 1; nxt[(c0, l)] = r
            else:
                nxt[(c0, l)] = [j, c0, l, 1]
        out.extend(open_.values()); open_ = nxt
    out.extend(open_.values())
    return out

LABEL = {"us": (-99, 39), "ca": (-106, 57), "no": (9.5, 61.5), "se": (15.5, 62.5), "jp": (138.5, 36.5), "ph": (122, 12.5),
         "nz": (172.5, -42), "it": (12.5, 42.8), "uk": (-1.8, 53), "cl": (-71, -32), "dk": (9.3, 56.1), "in": (79, 22),
         "au": (134, -25), "br": (-52, -11), "ar": (-65, -36), "fr": (2.4, 46.6), "es": (-3.7, 40), "pt": (-8.1, 39.6)}
total = 0
lines = ["-- AUTO-GENERATED by tools/gen_map2d.py from Natural Earth borders (world-atlas 2.0.2, public domain).",
         "-- Top-down world map, %d cells per degree, longitude %g..%g, latitude %g..%g. Small islands are left out." % (RES, LON0, LON1, TOP, BOT),
         "-- rects = { row, col, width, height } in cells (0-based). tone 1..4 = neutral land, cid = playable country.",
         "return {", "\tRES = %d," % RES, "\tW = %d," % W, "\tH = %d," % H, "\tLON0 = %g," % LON0, "\tLAT_TOP = %g," % TOP, "\tlayers = {"]
for c in countries:
    rr = rects(c["idx"])
    if not rr:
        continue
    total += len(rr)
    flat = ",".join("%d,%d,%d,%d" % tuple(r) for r in rr)
    if c["cid"]:
        big = max(c["parts"], key=lambda p: p.area)
        lon, lat = LABEL.get(c["cid"], (None, None))
        if lon is None:
            pt = big.representative_point() if big.centroid.within(big) is False else big.centroid
            lon, lat = pt.x, pt.y
        lines.append('\t\t{ cid = "%s", tone = %d, lat = %.2f, lon = %.2f, r = { %s } },' % (c["cid"], c["tone"], lat, lon, flat))
    else:
        lines.append("\t\t{ tone = %d, r = { %s } }," % (c["tone"], flat))
# the 3D map table in the office: the same land (no small islands), 1 degree, longitude -180..180
TW, TH = 360, int(TOP - BOT)
timg = Image.new("L", (TW, TH), 0)
tdraw = ImageDraw.Draw(timg)
def tpx(pt):
    x = pt[0] if pt[0] <= 180 else pt[0] - 360
    return (x + 180, TOP - pt[1])
for c in countries:
    for p in c["parts"]:
        pts = list(p.exterior.coords)
        if p.bounds[2] > 180 and p.bounds[0] < 180:
            # a part across 180 degrees: draw it twice (both ends of the table)
            tdraw.polygon([(q[0] + 180, TOP - q[1]) for q in pts], fill=1)
            tdraw.polygon([(q[0] - 180, TOP - q[1]) for q in pts], fill=1)
        else:
            tdraw.polygon([tpx(q) for q in pts], fill=1)
tp = timg.load()
truns = {}
for j in range(TH):
    i = 0
    while i < TW:
        if tp[i, j]:
            s0 = i
            while i < TW and tp[i, j]:
                i += 1
            truns.setdefault(j, []).append((s0, i - s0))
        else:
            i += 1
open_, trects = {}, []
for j in sorted(truns):
    nxt = {}
    for c0, l in truns[j]:
        if (c0, l) in open_ and open_[(c0, l)][0] + open_[(c0, l)][3] == j:
            r = open_.pop((c0, l)); r[3] += 1; nxt[(c0, l)] = r
        else:
            nxt[(c0, l)] = [j, c0, l, 1]
    trects.extend(open_.values()); open_ = nxt
trects.extend(open_.values())
lines += ["\t},", "\t-- the 3D map table: 1 degree cells, longitude -180..180 (TW x TH), same latitude range", "\tTW = %d," % TW, "\tTH = %d," % TH,
          "\ttable = { " + ",".join("%d,%d,%d,%d" % tuple(r) for r in trects) + " },", "}", ""]
print("table rects", len(trects))
open("src/Headliner/Data/WorldMap2D.lua", "w").write("\n".join(lines))
print("countries", len(countries), "rects", total, "size", W, H)
