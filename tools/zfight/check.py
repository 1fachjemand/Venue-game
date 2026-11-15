# Finds z-fighting: two visible box faces of different parts that lie in the same plane, point the same way and overlap.
# usage: python3 tools/zfight/check.py parts.txt [group-filter]
import sys, collections
import numpy as np
rows = [l.split() for l in open(sys.argv[1]) if l.strip()]
flt = sys.argv[2] if len(sys.argv) > 2 else ""
groups = collections.defaultdict(list)
for r in rows:
    if flt and flt not in r[0]: continue
    if r[2] not in ("Block",): continue
    if r[1].startswith("Fan") or r[1] in ("Phone", "Wristband", "Windows", "LaneDash"): continue
    if r[1].startswith("Arc") or r[1].startswith("Cont"): continue  # the street bends: pieces of one colour overlapping on purpose  # crowd figures never overlap each other  # balls, cylinders, meshes, wedges are skipped (curved / sloped)
    size = np.array(list(map(float, r[3:6])))
    pos = np.array(list(map(float, r[6:9])))
    R = np.array(list(map(float, r[9:18]))).reshape(3, 3)
    groups[r[0]].append((r[1], size, pos, R))
def faces(size, pos, R):
    out = []
    for ax in range(3):
        for sgn in (-1, 1):
            n = R[:, ax] * sgn
            c = pos + n * size[ax] / 2
            u, v = [k for k in range(3) if k != ax]
            out.append((n, c, R[:, u], size[u] / 2, R[:, v], size[v] / 2))
    return out
def overlap(f, g):
    # project g's rectangle corners into f's plane axes; rough test with 2D separating axes
    n, c, u, hu, v, hv = f
    n2, c2, u2, hu2, v2, hv2 = g
    def corners(cc, uu, hu_, vv, hv_):
        return [cc + uu * a * hu_ + vv * b * hv_ for a in (-1, 1) for b in (-1, 1)]
    A = [(np.dot(p - c, u), np.dot(p - c, v)) for p in corners(c, u, hu, v, hv)]
    B = [(np.dot(p - c, u), np.dot(p - c, v)) for p in corners(c2, u2, hu2, v2, hv2)]
    def axes(P):
        return [np.array([P[1][1] - P[0][1], -(P[1][0] - P[0][0])]), np.array([P[2][1] - P[0][1], -(P[2][0] - P[0][0])])]
    area_ok = True
    for ax in axes(A) + axes(B):
        if np.linalg.norm(ax) < 1e-9: continue
        a = [np.dot(ax, p) for p in A]; b = [np.dot(ax, p) for p in B]
        ov = min(max(a), max(b)) - max(min(a), min(b))
        if ov <= 0.05 * np.linalg.norm(ax): return False
    return True
report = collections.Counter()
examples = collections.defaultdict(list)
for gname, parts in groups.items():
    F = [(i, f) for i, p in enumerate(parts) for f in faces(p[1], p[2], p[3])]
    # bucket by plane: normal direction + offset
    buckets = collections.defaultdict(list)
    for i, f in F:
        n, c = f[0], f[1]
        key = (round(n[0], 2), round(n[1], 2), round(n[2], 2), round(float(np.dot(n, c)) / 0.02))
        buckets[key].append((i, f))
    seen = set()
    for key, lst in buckets.items():
        if key[1] < -0.9:  # faces looking down (bottoms) are hidden from every camera in the game
            continue
        for a in range(len(lst)):
            for b in range(a + 1, len(lst)):
                i, f = lst[a]; j, g = lst[b]
                if i == j or (i, j) in seen: continue
                if overlap(f, g):
                    seen.add((i, j))
                    report[gname] += 1
                    pair = "/".join(sorted((parts[i][0], parts[j][0])))
                    if pair not in examples[gname]: examples[gname].append(pair)
for g, n in report.most_common():
    print(f"{n:5d}  {g}   e.g. {', '.join(examples[g])}")
print("groups with z-fighting:", len(report), "of", len(groups))
