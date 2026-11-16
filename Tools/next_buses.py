#!/usr/bin/env python3
"""Print the next buses at a Translink stop, straight from the live feed.

This is a line-for-line port of Shared/Core/ProtobufReader.swift and
GTFSRealtimeParser.swift, with no dependencies beyond the standard library.
It's useful for checking the feed (or a new stop ID) without building the app.

    python3 Tools/next_buses.py            # Adelaide St Stop 30
    python3 Tools/next_buses.py 000030 --walk 5 --routes 195,199
"""

import argparse
import gzip
import sys
import time
import urllib.request

FEED_URL = "https://gtfsrt.api.translink.com.au/api/realtime/SEQ/TripUpdates/Bus"
TRIP_CANCELED = 3
STOP_SKIPPED = 1


class Reader:
    def __init__(self, data, start=0, end=None):
        self.data = data
        self.pos = start
        self.end = len(data) if end is None else end

    def at_end(self):
        return self.pos >= self.end

    def varint(self):
        result, shift = 0, 0
        while True:
            if self.pos >= self.end:
                raise ValueError("truncated")
            b = self.data[self.pos]
            self.pos += 1
            if shift < 64:
                result |= (b & 0x7F) << shift
            if not b & 0x80:
                return result & 0xFFFFFFFFFFFFFFFF
            shift += 7
            if shift >= 70:
                raise ValueError("malformed varint")

    def tag(self):
        key = self.varint()
        return key >> 3, key & 7

    def int64(self):
        v = self.varint()
        return v - (1 << 64) if v >= 1 << 63 else v

    def int32(self):
        v = self.int64() & 0xFFFFFFFF
        return v - (1 << 32) if v >= 1 << 31 else v

    def _range(self):
        length = self.varint()
        if length > self.end - self.pos:
            raise ValueError("truncated")
        start = self.pos
        self.pos += length
        return start, self.pos

    def string(self):
        s, e = self._range()
        return self.data[s:e].decode("utf-8", "replace")

    def message(self):
        s, e = self._range()
        return Reader(self.data, s, e)

    def skip(self, wire):
        if wire == 0:
            self.varint()
        elif wire == 1:
            self._advance(8)
        elif wire == 2:
            self._range()
        elif wire == 5:
            self._advance(4)
        else:
            raise ValueError(f"unsupported wire type {wire}")

    def _advance(self, n):
        if self.end - self.pos < n:
            raise ValueError("truncated")
        self.pos += n


def parse_event(r):
    t = d = None
    while not r.at_end():
        f, w = r.tag()
        if (f, w) == (1, 0):
            d = r.int32()
        elif (f, w) == (2, 0):
            t = r.int64()
        else:
            r.skip(w)
    return t, d


def parse_stop_time_update(r, stop_id):
    sid, rel = "", 0
    arr = dep = (None, None)
    while not r.at_end():
        f, w = r.tag()
        if (f, w) == (2, 2):
            arr = parse_event(r.message())
        elif (f, w) == (3, 2):
            dep = parse_event(r.message())
        elif (f, w) == (4, 2):
            sid = r.string()
        elif (f, w) == (5, 0):
            rel = r.varint()
        else:
            r.skip(w)
    if sid != stop_id or rel == STOP_SKIPPED:
        return None
    if dep[0] is not None:
        return dep[0], dep[1] if dep[1] is not None else arr[1]
    if arr[0] is not None:
        return arr
    return None


def parse_trip_update(r, stop_id):
    trip_id, route_id, canceled, match = "", "", False, None
    while not r.at_end():
        f, w = r.tag()
        if (f, w) == (1, 2):
            t = r.message()
            while not t.at_end():
                tf, tw = t.tag()
                if (tf, tw) == (1, 2):
                    trip_id = t.string()
                elif (tf, tw) == (4, 0):
                    canceled = t.varint() == TRIP_CANCELED
                elif (tf, tw) == (5, 2):
                    route_id = t.string()
                else:
                    t.skip(tw)
        elif (f, w) == (2, 2) and match is None:
            match = parse_stop_time_update(r.message(), stop_id)
        else:
            r.skip(w)
    if canceled or match is None:
        return None
    return {"trip_id": trip_id, "route_id": route_id, "time": match[0], "delay": match[1]}


def parse_feed(data, stop_id):
    r = Reader(data)
    ts, arrivals = None, []
    while not r.at_end():
        f, w = r.tag()
        if (f, w) == (1, 2):
            h = r.message()
            while not h.at_end():
                hf, hw = h.tag()
                if (hf, hw) == (3, 0):
                    ts = h.varint()
                else:
                    h.skip(hw)
        elif (f, w) == (2, 2):
            e = r.message()
            deleted, arrival = False, None
            while not e.at_end():
                ef, ew = e.tag()
                if (ef, ew) == (2, 0):
                    deleted = e.varint() != 0
                elif (ef, ew) == (3, 2):
                    arrival = parse_trip_update(e.message(), stop_id)
                else:
                    e.skip(ew)
            if arrival and not deleted:
                arrivals.append(arrival)
        else:
            r.skip(w)
    return ts, arrivals


def normalize_stop_id(raw):
    text = raw.strip()
    if "stops/" in text:
        text = text.split("stops/", 1)[1]
        for ch in "/?#":
            text = text.split(ch, 1)[0]
    if not text:
        return "30"
    return text.lstrip("0") or "0"


def fetch():
    req = urllib.request.Request(FEED_URL, headers={"Accept-Encoding": "gzip"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        body = resp.read()
        if resp.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)
    return body


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("stop", nargs="?", default="000030", help="stop ID or Translink stop URL")
    p.add_argument("--walk", type=int, default=5, help="minutes to walk to the stop")
    p.add_argument("--routes", default="", help="comma-separated route filter, e.g. 195,199")
    p.add_argument("--file", help="parse a saved feed file instead of downloading")
    args = p.parse_args()

    stop_id = normalize_stop_id(args.stop)
    routes = {r.strip().upper() for r in args.routes.replace(";", ",").replace(" ", ",").split(",") if r.strip()}
    data = open(args.file, "rb").read() if args.file else fetch()
    ts, arrivals = parse_feed(data, stop_id)
    now = time.time()

    rows, seen = [], set()
    for a in sorted(arrivals, key=lambda a: a["time"]):
        route = a["route_id"].split("-")[0]
        if routes and route.upper() not in routes:
            continue
        if a["time"] - now <= -30 or a["trip_id"] in seen:
            continue
        seen.add(a["trip_id"])
        rows.append((route, a))

    print(f"Stop {stop_id}: {len(rows)} upcoming (feed generated {time.strftime('%H:%M:%S', time.localtime(ts)) if ts else '?'})")
    for route, a in rows[:12]:
        mins = max(0, int((a["time"] - now) // 60))
        leave = max(0, int((a["time"] - args.walk * 60 - now) // 60))
        delay = a["delay"]
        late = "" if delay is None else f"  ({'+' if delay >= 0 else ''}{round(delay / 60)} min)"
        when = time.strftime("%H:%M", time.localtime(a["time"]))
        leave_txt = "too late to walk" if a["time"] - args.walk * 60 - now < -30 else ("leave now" if leave == 0 else f"leave in {leave} min")
        print(f"  {route:>5}  {when}  in {mins:>2} min  {leave_txt}{late}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
