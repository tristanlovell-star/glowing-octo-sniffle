#!/usr/bin/env python3
"""Builds ApexGP/Resources/tracks.json from real F1 circuit layouts.

The layouts come from Tomislav Bacinger's f1-circuits dataset (MIT licence):
https://github.com/bacinger/f1-circuits

    python3 ApexGP/Tools/make_tracks.py              # downloads the dataset
    python3 ApexGP/Tools/make_tracks.py f1.geojson   # or uses a local copy

Each circuit's GPS centreline is turned into flat metres (x = east,
z = south, so it drops straight into SceneKit where -z is "north"). Where a
track crosses itself (Suzuka's figure eight) the later section is lifted
onto a bridge.
"""
import json
import math
import sys
import urllib.request
from pathlib import Path

URL = "https://raw.githubusercontent.com/bacinger/f1-circuits/master/f1-circuits.geojson"

# The 2026 calendar, in race order: (dataset id, display name, country, flag, road width m)
CALENDAR = [
    ("au-1953", "Albert Park", "Australia", "🇦🇺", 14),
    ("cn-2004", "Shanghai", "China", "🇨🇳", 15),
    ("jp-1962", "Suzuka", "Japan", "🇯🇵", 13),
    ("bh-2002", "Sakhir", "Bahrain", "🇧🇭", 15),
    ("sa-2021", "Jeddah", "Saudi Arabia", "🇸🇦", 13),
    ("us-2022", "Miami", "USA", "🇺🇸", 14),
    ("ca-1978", "Montréal", "Canada", "🇨🇦", 13),
    ("mc-1929", "Monaco", "Monaco", "🇲🇨", 11),
    ("es-1991", "Barcelona", "Spain", "🇪🇸", 14),
    ("at-1969", "Red Bull Ring", "Austria", "🇦🇹", 14),
    ("gb-1948", "Silverstone", "Great Britain", "🇬🇧", 15),
    ("be-1925", "Spa-Francorchamps", "Belgium", "🇧🇪", 14),
    ("hu-1986", "Hungaroring", "Hungary", "🇭🇺", 13),
    ("nl-1948", "Zandvoort", "Netherlands", "🇳🇱", 12),
    ("it-1922", "Monza", "Italy", "🇮🇹", 14),
    ("es-2026", "Madring", "Spain", "🇪🇸", 13),
    ("az-2016", "Baku", "Azerbaijan", "🇦🇿", 12),
    ("sg-2008", "Marina Bay", "Singapore", "🇸🇬", 12),
    ("us-2012", "Circuit of the Americas", "Austin, USA", "🇺🇸", 15),
    ("mx-1962", "Mexico City", "Mexico", "🇲🇽", 14),
    ("br-1940", "Interlagos", "Brazil", "🇧🇷", 14),
    ("us-2023", "Las Vegas", "USA", "🇺🇸", 14),
    ("qa-2004", "Lusail", "Qatar", "🇶🇦", 14),
    ("ae-2009", "Yas Marina", "Abu Dhabi", "🇦🇪", 15),
]

# Circuits whose dataset points run against the race direction.
REVERSED = {"sg-2008"}  # Marina Bay runs anti-clockwise.

BRIDGE_HEIGHT = 8.0   # metres
BRIDGE_RAMP = 260.0   # metres either side of the crossing


def to_metres(coords):
    lon0, lat0 = coords[0]
    kx = math.cos(math.radians(lat0)) * 111320.0
    ky = 110540.0
    return [((lon - lon0) * kx, -(lat - lat0) * ky) for lon, lat in coords]


def seg_intersect(p1, p2, p3, p4):
    """Returns t along p1->p2 where it crosses p3->p4, or None."""
    d = (p2[0] - p1[0]) * (p4[1] - p3[1]) - (p2[1] - p1[1]) * (p4[0] - p3[0])
    if abs(d) < 1e-9:
        return None
    t = ((p3[0] - p1[0]) * (p4[1] - p3[1]) - (p3[1] - p1[1]) * (p4[0] - p3[0])) / d
    u = ((p3[0] - p1[0]) * (p2[1] - p1[1]) - (p3[1] - p1[1]) * (p2[0] - p1[0])) / d
    if 0 <= t <= 1 and 0 <= u <= 1:
        return t, u
    return None


def heights_for(pts):
    n = len(pts)
    arc = [0.0]
    for i in range(1, n):
        arc.append(arc[-1] + math.dist(pts[i - 1], pts[i]))
    total = arc[-1] + math.dist(pts[-1], pts[0])
    crossings = []
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        for j in range(i + 2, n):
            if (j + 1) % n == i:
                continue
            hit = seg_intersect(a, b, pts[j], pts[(j + 1) % n])
            if hit:
                sj = arc[j] + hit[1] * math.dist(pts[j], pts[(j + 1) % n])
                crossings.append(sj)
    if not crossings:
        return None
    h = [0.0] * n
    for sj in crossings:
        for k in range(n):
            d = abs(arc[k] - sj)
            d = min(d, total - d)
            if d < BRIDGE_RAMP:
                h[k] = max(h[k], BRIDGE_HEIGHT * (0.5 + 0.5 * math.cos(math.pi * d / BRIDGE_RAMP)))
    return [round(v, 2) for v in h]


def main():
    if len(sys.argv) > 1:
        data = json.loads(Path(sys.argv[1]).read_text())
    else:
        with urllib.request.urlopen(URL) as r:
            data = json.load(r)
    by_id = {f["properties"]["id"]: f for f in data["features"]}
    out = []
    for cid, name, country, flag, width in CALENDAR:
        f = by_id[cid]
        coords = f["geometry"]["coordinates"]
        if coords[0] == coords[-1]:
            coords = coords[:-1]
        if cid in REVERSED:
            coords = [coords[0]] + coords[1:][::-1]
        pts = to_metres(coords)
        track = {
            "id": cid,
            "name": name,
            "fullName": f["properties"]["Name"],
            "country": country,
            "flag": flag,
            "lengthMeters": f["properties"]["length"],
            "width": width,
            "points": [[round(x, 1), round(z, 1)] for x, z in pts],
        }
        h = heights_for(pts)
        if h:
            track["heights"] = h
            print(f"{name}: bridge over {sum(1 for v in h if v > 0)} points")
        out.append(track)
    dest = Path(__file__).resolve().parent.parent / "Resources" / "tracks.json"
    dest.write_text(json.dumps({"source": URL, "licence": "MIT, (c) Tomislav Bacinger", "tracks": out},
                               ensure_ascii=False, separators=(",", ":")))
    print(f"wrote {len(out)} tracks to {dest}")


if __name__ == "__main__":
    main()
