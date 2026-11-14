# Draws a MenuCity data module from above (PNG) to check it: python3 tools/osm/preview.py <name> <out.png> [half]
import sys, re, math
from PIL import Image, ImageDraw
name, out = sys.argv[1], sys.argv[2]
src = open(f"src/Headliner/Data/MenuCity/{name}.lua").read()
def arr(key):
    m = re.search(r"\t" + key + r" = \{(.*?)\n\t\},", src, re.S)
    return [int(x) for x in re.findall(r"-?\d+", m.group(1))] if m else []
half = int(sys.argv[3]) if len(sys.argv) > 3 else int(re.search(r"half = (\d+)", src).group(1))
N = 1400
img = Image.new("RGB", (N, N), (40, 42, 46))
d = ImageDraw.Draw(img)
def P(x, z):
    return ((x + half) / (2 * half) * N, (z + half) / (2 * half) * N)
def rect(v, i, col):
    x, z, w, dd, yaw = v[i:i + 5]
    a = math.radians(yaw)
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = sx * w / 2, sz * dd / 2
        pts.append(P(x + lx * math.cos(a) - lz * math.sin(a), z + lx * math.sin(a) + lz * math.cos(a)))
    d.polygon(pts, fill=col)
G, W, Pl, R, B = arr("G"), arr("W"), arr("P"), arr("R"), arr("B")
for i in range(0, len(G), 5): rect(G, i, (40, 80, 44))
for i in range(0, len(W), 5): rect(W, i, (30, 60, 110))
for i in range(0, len(Pl), 5): rect(Pl, i, (110, 110, 114))
COL = {1: (230, 160, 60), 2: (200, 200, 200), 3: (150, 150, 150), 4: (110, 110, 110), 5: (170, 170, 160), 6: (120, 80, 60), 7: (60, 140, 220)}
for i in range(0, len(R), 6):
    x1, z1, x2, z2, w, k = R[i:i + 6]
    d.line([P(x1, z1), P(x2, z2)], fill=COL.get(k % 10, (255, 0, 255)), width=max(1, int(w / (2 * half) * N)))
for i in range(0, len(B), 8):
    h = B[i + 5]
    c = min(255, 70 + h)
    rect(B, i, (c, c - 20, c - 40))
d.ellipse([P(-12, -12), P(12, 12)], fill=(255, 0, 0))
step = 400 if half > 1200 else 200
for g in range(-half // step * step, half + 1, step):
    d.line([P(g, -half), P(g, half)], fill=(255, 255, 0) if g == 0 else (90, 90, 40), width=1)
    d.line([P(-half, g), P(half, g)], fill=(255, 255, 0) if g == 0 else (90, 90, 40), width=1)
    d.text(P(g + 4, -half + 4), str(g), fill=(255, 255, 120))
    d.text(P(-half + 4, g + 4), str(g), fill=(255, 255, 120))
xs = re.search(r"X = \{ ([^}]*) \}", src)
if xs:
    xv = [int(v) for v in xs.group(1).split(",")]
    for i in range(0, len(xv), 5):
        if xv[i + 2] > 0: rect(xv, i, (200, 40, 200))
img.save(out)
