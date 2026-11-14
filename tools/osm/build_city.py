# Turns OpenMapTiles vector tiles (see fetch_tiles.py) into a compact Lua data module for the main-menu scenes.
# Map data (c) OpenStreetMap contributors, ODbL (via OpenFreeMap / OpenMapTiles).
# usage: python3 tools/osm/build_city.py <tile cache> <scene name>   (scenes are defined in SCENES below)
import sys, os, glob, gzip, math, random
import mapbox_vector_tile
from shapely.geometry import shape, Polygon, MultiPolygon, LineString, MultiLineString, box, Point
from shapely.affinity import rotate, translate, scale as sscale
from shapely.ops import unary_union
from shapely.prepared import prep

S = 2.0  # studs per metre
SCENES = {
    # name: centre (lat, lon) = venue centre, rot = degrees to turn the map (venue long axis -> x), half = half size in m,
    # exclude = circles (lat, lon, r m) whose buildings are replaced by hand-made models, anchors = named points
    "o3": dict(c=(51.50302, 0.00322), rot=0, half=1300, exclude=[(51.50302, 0.00322, 200)], anchors={}),
    "msg": dict(c=(40.75051, -73.99341), rot=-29, half=1000, exclude=[(40.75051, -73.99341, 70), (40.74844, -73.98566, 40)], anchors={"empire": (40.74844, -73.98566), "penn": (40.75040, -73.99510)}),
    "lanxus": dict(c=(50.93838, 6.98300), rot=0, half=1500, box=(-2150, -900, 800, 900), exclude=[(50.93838, 6.98300, 95), (50.94130, 6.95825, 80)], anchors={"dom": (50.94130, 6.95825), "bridge": (50.94030, 6.96550)}),
    "zurich": dict(c=(47.41172, 8.55167), rot=0, half=1100, exclude=[(47.41172, 8.55167, 75)], anchors={}),
    "paris": dict(c=(48.92447, 2.36016), rot=0, half=1200, exclude=[(48.92447, 2.36016, 170)], anchors={}),
    "madrid": dict(c=(40.45306, -3.68835), rot=0, half=1100, exclude=[(40.45306, -3.68835, 130)], anchors={}),
    "wembley": dict(c=(51.55600, -0.27959), rot=0, half=1200, exclude=[(51.55600, -0.27959, 170)], anchors={"station": (51.5634, -0.2795)}),
}

def lonlat(z, tx, ty, px, py):
    n = 2 ** z
    lon = (tx + px / 4096) / n * 360 - 180
    yy = (ty + py / 4096) / n
    lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * yy))))
    return lon, lat

def main(cache, name):
    cfg = SCENES[name]
    lat0, lon0 = cfg["c"]
    mlat, mlon = 110540.0, 111320.0 * math.cos(math.radians(lat0))
    rot = math.radians(cfg["rot"])
    def local(lon, lat):
        # metres east (+x) and south (+z), turned by rot, in studs
        x = (lon - lon0) * mlon
        z = -(lat - lat0) * mlat
        xr = x * math.cos(rot) - z * math.sin(rot)
        zr = x * math.sin(rot) + z * math.cos(rot)
        return xr * S, zr * S
    half = cfg["half"] * S
    area = box(-half, -half, half, half)
    if "box" in cfg:
        x0, z0, x1, z1 = cfg["box"]
        area = box(x0 * S, z0 * S, x1 * S, z1 * S)
    excl = [(Point(*local(lo, la)), r * S) for la, lo, r in cfg["exclude"]]
    buildings, roads, water, green, plaza = [], [], [], [], []
    for f in sorted(glob.glob(os.path.join(cache, "14_*.pbf"))):
        _, tx, ty = os.path.basename(f)[:-4].split("_")
        tx, ty = int(tx), int(ty)
        raw = open(f, "rb").read()
        if raw[:2] == b"\x1f\x8b":
            raw = gzip.decompress(raw)
        t = mapbox_vector_tile.decode(raw, default_options={"y_coord_down": True})
        def conv(geom):
            # tile pixels -> local studs, clipped to the tile itself (tiles overlap a little)
            g = shape(geom)
            if g.geom_type in ("Polygon", "MultiPolygon") and not g.is_valid:
                g = g.buffer(0)
            try:
                g = g.intersection(box(0, 0, 4096, 4096))
            except Exception:
                return []
            def tr(coords):
                return [local(*lonlat(14, tx, ty, x, y)) for x, y in coords]
            def tp(p):
                return Polygon(tr(p.exterior.coords), [tr(i.coords) for i in p.interiors])
            out = []
            for gg in getattr(g, "geoms", [g]):
                if gg.is_empty:
                    continue
                if gg.geom_type == "Polygon":
                    out.append(tp(gg))
                elif gg.geom_type == "LineString":
                    out.append(LineString(tr(gg.coords)))
            return out
        for ft in t.get("building", {}).get("features", []):
            h = ft["properties"].get("render_height", 0) or 0
            mh = ft["properties"].get("render_min_height", 0) or 0
            if ft["properties"].get("hide_3d"):
                continue
            for p in conv(ft["geometry"]):
                if p.geom_type == "Polygon" and p.area > 30 * S * S:
                    buildings.append((p, max(h, 6), mh))
        for ft in t.get("transportation", {}).get("features", []):
            pr = ft["properties"]
            if pr.get("brunnel") == "tunnel":
                continue
            cl, sub = pr.get("class", ""), pr.get("subclass", "")
            for g in conv(ft["geometry"]):
                if g.geom_type == "Polygon":
                    if cl in ("path", "minor", "service") or sub == "pedestrian":
                        plaza.append(g)
                    continue
                roads.append((g, cl, sub, pr.get("brunnel") == "bridge"))
        for ft in t.get("water", {}).get("features", []):
            if ft["properties"].get("class") == "swimming_pool":
                continue
            for p in conv(ft["geometry"]):
                if p.geom_type == "Polygon":
                    water.append(p)
        for layer in ("park", "landcover"):
            for ft in t.get(layer, {}).get("features", []):
                cl = ft["properties"].get("class", "")
                if layer == "landcover" and cl not in ("grass", "wood", "farmland"):
                    continue
                for p in conv(ft["geometry"]):
                    if p.geom_type == "Polygon":
                        green.append(p)
    # ---- rectangles: polygons -> a few rotated boxes
    def rects(poly, cell, maxn=10):
        poly = poly.buffer(0)
        if poly.is_empty or poly.area < 4:
            return []
        if poly.geom_type == "MultiPolygon":
            out = []
            for p in poly.geoms:
                out += rects(p, cell, maxn)
            return out
        mrr = poly.minimum_rotated_rectangle
        if mrr.geom_type != "Polygon":
            return []
        cs = list(mrr.exterior.coords)
        e1 = (cs[1][0] - cs[0][0], cs[1][1] - cs[0][1])
        e2 = (cs[2][0] - cs[1][0], cs[2][1] - cs[1][1])
        L1, L2 = math.hypot(*e1), math.hypot(*e2)
        ang = math.atan2(e1[1], e1[0]) if L1 >= L2 else math.atan2(e2[1], e2[0])
        c = mrr.centroid
        if poly.area / max(mrr.area, 1e-6) > 0.86:
            return [(c.x, c.y, max(L1, L2), min(L1, L2), math.degrees(ang))]
        # rasterise in the box frame and merge cells into rectangles
        p2 = rotate(poly, -ang, origin=c, use_radians=True)
        x0, y0, x1, y1 = p2.bounds
        while True:
            nx, ny = max(1, int((x1 - x0) / cell)), max(1, int((y1 - y0) / cell))
            if nx * ny <= 1600:
                break
            cell *= 1.4
        cw, chh = (x1 - x0) / nx, (y1 - y0) / ny
        pp = prep(p2)
        grid = [[pp.contains(Point(x0 + (i + 0.5) * cw, y0 + (j + 0.5) * chh)) for i in range(nx)] for j in range(ny)]
        out, open_ = [], {}
        for j in range(ny):
            runs, i = [], 0
            while i < nx:
                if grid[j][i]:
                    s0 = i
                    while i < nx and grid[j][i]:
                        i += 1
                    runs.append((s0, i - s0))
                else:
                    i += 1
            nxt = {}
            for r in runs:
                if r in open_:
                    o = open_.pop(r); o[3] += 1; nxt[r] = o
                else:
                    nxt[r] = [j, r[0], r[1], 1]
            out += list(open_.values()); open_ = nxt
        out += list(open_.values())
        if len(out) > maxn and cell < 60:
            return rects(poly, cell * 1.6, maxn)
        res = []
        ca, sa = math.cos(ang), math.sin(ang)
        for j, i, w, hh in out:
            lx, ly = x0 + (i + w / 2) * cw - c.x, y0 + (j + hh / 2) * chh - c.y
            res.append((c.x + lx * ca - ly * sa, c.y + lx * sa + ly * ca, w * cw, hh * chh, math.degrees(ang)))
        return res
    random.seed(7)
    # footprints of the replaced buildings (venue, landmarks): {x, z, w, d, yaw} of their outline box
    dropped = [[] for _ in excl]
    for p, h, mh in buildings:
        cpt = p.centroid
        for k, e in enumerate(excl):
            if cpt.distance(e[0]) < e[1]:
                dropped[k].append(p)
                break
    X = []
    for k, polys in enumerate(dropped):
        if not polys:
            e = excl[k]
            X += [round(e[0].x), round(e[0].y), 0, 0, 0]
            continue
        big = max(polys, key=lambda q: q.area)
        keep = [q for q in polys if q.area > big.area * 0.08 and q.distance(big) < 10 * S]
        u = unary_union([q.buffer(0) for q in keep])
        print("  replaced", k, len(polys), "polys, used", len(keep), "areas m2", sorted([round(q.area / S / S) for q in polys], reverse=True)[:6])
        r = rects(u.convex_hull, 1000, 1)[0]
        X += [round(r[0]), round(r[1]), round(r[2]), round(r[3]), round(r[4]) % 180]
    focus = [e[0] for e in excl]
    def far(pt):
        return min(pt.distance(f) for f in focus) / S  # metres to the nearest venue / landmark
    B = []
    for p, h, mh in buildings:
        if not p.intersects(area):
            continue
        cpt = p.centroid
        if any(cpt.distance(e[0]) < e[1] for e in excl):
            continue
        dm = far(cpt)
        if p.area / (S * S) < 40 + (dm / 480) ** 2 * 260:
            continue
        for x, z, w, d, yaw in rects(p, 6 * S, 8):
            if w < 3 or d < 3:
                continue
            B += [round(x), round(z), round(w), round(d), round(yaw) % 180, round(h * S), round(mh * S), random.randint(1, 6)]
    WID = {"motorway": 15, "trunk": 13, "primary": 12, "secondary": 10, "tertiary": 9, "minor": 7, "service": 4.5, "rail": 3.5, "transit": 3, "pedestrian": 4, "raceway": 8}
    KIND = {"motorway": 1, "trunk": 1, "primary": 2, "secondary": 2, "tertiary": 3, "minor": 3, "service": 4, "rail": 6, "transit": 7, "pedestrian": 5}
    R = []
    for g, cl, sub, bridge in roads:
        key = "pedestrian" if sub == "pedestrian" else cl
        if key not in WID or not g.intersects(area):
            continue
        if cl == "rail" and sub in ("subway",):
            continue
        dm = far(g.centroid)
        if (key in ("service", "pedestrian") and dm > 650) or (key == "minor" and dm > 1100):
            continue
        g = g.intersection(area).simplify(1.5 * S)
        for gg in getattr(g, "geoms", [g]):
            if gg.geom_type != "LineString":
                continue
            cs = list(gg.coords)
            for a, b in zip(cs, cs[1:]):
                if math.hypot(b[0] - a[0], b[1] - a[1]) < 1:
                    continue
                k = KIND[key] + (10 if bridge else 0)
                if cl == "transit" or sub in ("tram", "light_rail"):
                    k = 7 + (10 if bridge else 0)
                R += [round(a[0]), round(a[1]), round(b[0]), round(b[1]), round(WID[key] * S), k]
    def flat(polys, cell, maxn):
        out = []
        u = unary_union([p.buffer(0) for p in polys if not p.is_empty]).intersection(area)
        for p in getattr(u, "geoms", [u]):
            if p.is_empty or p.geom_type != "Polygon" or p.area < 200:
                continue
            for x, z, w, d, yaw in rects(p, cell, maxn):
                out += [round(x), round(z), round(w) + 1, round(d) + 1, round(yaw) % 180]
        return out
    def each(polys, cell, maxn, minArea):
        # every polygon on its own (a union would turn diagonal canals into staircases)
        out = []
        for poly in polys:
            p = poly.buffer(0).intersection(area)
            for q in getattr(p, "geoms", [p]):
                if q.is_empty or q.geom_type != "Polygon" or q.area < minArea:
                    continue
                for x, z, w, d, yaw in rects(q, cell, maxn):
                    if w >= 2 and d >= 2:
                        out += [round(x), round(z), round(w) + 1, round(d) + 1, round(yaw) % 180]
        return out
    Wt = each(water, 5 * S, 80, 100)
    G = each([g for g in green if far(g.centroid) < 1300], 8 * S, 16, 400)
    P = each(plaza, 4 * S, 10, 100)
    A = {k: [round(v) for v in local(lo, la)] for k, (la, lo) in cfg["anchors"].items()}
    def arr(name, v, per):
        lines = []
        for i in range(0, len(v), per * 8):
            lines.append("\t\t" + ",".join(str(int(x)) for x in v[i:i + per * 8]) + ",")
        return f"\t{name} = {{\n" + "\n".join(lines) + "\n\t},"
    out = ["-- AUTO-GENERATED by tools/osm/build_city.py. Map data (c) OpenStreetMap contributors, ODbL (OpenFreeMap / OpenMapTiles).",
           "-- B = buildings {x, z, w, d, yaw, h, minH, style}, R = roads {x1, z1, x2, z2, width, kind}, W/G/P = water/green/plaza {x, z, w, d, yaw}",
           "-- studs (1 stud = 0.5 m), venue at (0, 0), north = -z" + (f" (map turned {cfg['rot']} deg)" if cfg["rot"] else ""),
           "return {", f"\thalf = {round(half)},",
           arr("B", B, 8), arr("R", R, 6), arr("W", Wt, 5), arr("G", G, 5), arr("P", P, 5),
           "\tX = { " + ",".join(str(int(v)) for v in X) + " },",
           "\tA = { " + ", ".join(f"{k} = {{ {v[0]}, {v[1]} }}" for k, v in A.items()) + " },", "}", ""]
    os.makedirs("src/Headliner/Data/MenuCity", exist_ok=True)
    path = f"src/Headliner/Data/MenuCity/{name}.lua"
    open(path, "w").write("\n".join(out))
    print(name, "buildings", len(B) // 8, "road segs", len(R) // 6, "water", len(Wt) // 5, "green", len(G) // 5, "plaza", len(P) // 5, "bytes", os.path.getsize(path))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
