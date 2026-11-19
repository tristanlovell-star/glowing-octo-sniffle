#!/usr/bin/env python3
"""Builds Shared/Resources/stops.csv (stop_id,lat,lon,name) from Translink's
static GTFS feed, so the app can show stop names and pick the nearest stop.

    python3 Tools/make_stops.py              # downloads the GTFS zip (~40 MB)
    python3 Tools/make_stops.py SEQ_GTFS.zip # or use one you already have
"""
import csv, io, sys, urllib.request, zipfile
from pathlib import Path

URL = "https://gtfsrt.api.translink.com.au/GTFS/SEQ_GTFS.zip"

def main():
    data = open(sys.argv[1], "rb").read() if len(sys.argv) > 1 else urllib.request.urlopen(URL, timeout=120).read()
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        rows = list(csv.DictReader(io.TextIOWrapper(z.open("stops.txt"), "utf-8-sig")))
    out = Path(__file__).resolve().parent.parent / "Shared/Resources/stops.csv"
    n = 0
    with open(out, "w", newline="") as f:
        for r in rows:
            if r.get("location_type", "0") not in ("", "0"):
                continue  # skip stations/entrances; keep boardable stops
            name = r["stop_name"].replace("\n", " ").strip()
            f.write(f'{r["stop_id"]},{float(r["stop_lat"]):.6f},{float(r["stop_lon"]):.6f},{name}\n')
            n += 1
    print(f"wrote {n} stops to {out}")

if __name__ == "__main__":
    main()
