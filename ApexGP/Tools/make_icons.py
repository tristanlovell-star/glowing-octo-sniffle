#!/usr/bin/env python3
"""Draws the Apple TV app icon (layered) and Top Shelf images for Apex GP.

    python3 ApexGP/Tools/make_icons.py

Writes ApexGP/App/Assets.xcassets/App Icon & Top Shelf Image.brandassets.
The track drawn on the icon is Circuit of the Americas, in Austin.
"""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App" / "Assets.xcassets"
BRAND = ASSETS / "App Icon & Top Shelf Image.brandassets"
INFO = {"author": "xcode", "version": 1}

RED = (225, 26, 32)
GOLD = (255, 204, 51)
NIGHT = (14, 16, 24)

FONTS = [
    "/usr/share/fonts/opentype/inter/Inter-ExtraBoldItalic.otf",
    "/usr/share/fonts/truetype/freefont/FreeSansBoldOblique.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf",
]


def font(size):
    for f in FONTS:
        if Path(f).exists():
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def track_outline(track_id="us-2012"):
    data = json.loads((ROOT / "Resources" / "tracks.json").read_text())
    t = next(t for t in data["tracks"] if t["id"] == track_id)
    xs = [p[0] for p in t["points"]]
    ys = [p[1] for p in t["points"]]
    size = max(max(xs) - min(xs), max(ys) - min(ys))
    return [((x - min(xs)) / size, (y - min(ys)) / size) for x, y in zip(xs, ys)], \
        ((max(xs) - min(xs)) / size, (max(ys) - min(ys)) / size)


def back(w, h):
    img = Image.new("RGB", (w, h), NIGHT)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=(int(20 + 30 * t), int(22 + 10 * t), int(40 - 10 * t)))
    # Speed streaks
    for i in range(14):
        y = int(h * (0.15 + 0.05 * i))
        d.line([(int(w * 0.05 * (i % 4)), y), (w, y - int(h * 0.25))], fill=(52, 50, 70), width=max(1, h // 160))
    # Kerb stripe along the bottom
    k = max(6, h // 14)
    for i in range(0, w + k * 2, k * 2):
        d.polygon([(i, h - k), (i + k, h - k), (i + k - k // 2, h), (i - k // 2, h)], fill=RED)
        d.polygon([(i + k, h - k), (i + 2 * k, h - k), (i + 2 * k - k // 2, h), (i + k - k // 2, h)], fill=(240, 240, 240))
    return img


def middle(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pts, (tw, th) = track_outline()
    box = min(w * 0.42, h * 0.62)
    ox, oy = w * 0.70 - box * tw / 2, h * 0.42 - box * th / 2
    path = [(ox + x * box, oy + y * box) for x, y in pts]
    d = ImageDraw.Draw(img)
    lw = max(3, int(h * 0.028))
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).line(path + [path[0]], fill=GOLD + (200,), width=lw * 3, joint="curve")
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(lw)))
    d.line(path + [path[0]], fill=(255, 255, 255, 255), width=lw, joint="curve")
    r = lw * 1.4
    d.ellipse([path[0][0] - r, path[0][1] - r, path[0][0] + r, path[0][1] + r], fill=RED + (255,))
    return img


def front(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(int(h * 0.30))
    text = "APEX GP"
    tb = d.textbbox((0, 0), text, font=f)
    x, y = w * 0.07, h * 0.52
    d.text((x + h * 0.012, y + h * 0.012), text, font=f, fill=(0, 0, 0, 160))
    d.text((x, y), text, font=f, fill=(255, 255, 255, 255))
    # Underline swoosh
    uy = y + (tb[3] - tb[1]) + h * 0.09
    d.polygon([(x, uy), (x + (tb[2] - tb[0]) * 1.05, uy - h * 0.02), (x + (tb[2] - tb[0]) * 1.0, uy + h * 0.02), (x, uy + h * 0.03)], fill=RED + (255,))
    return img


def write_json(path, obj):
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(obj, indent=2) + "\n")


def imagestack(name, sizes):
    """sizes: list of (scale, w, h)."""
    stack = BRAND / f"{name}.imagestack"
    layers = [("Front", front), ("Middle", middle), ("Back", back)]
    write_json(stack, {"info": INFO, "layers": [{"filename": f"{n}.imagestacklayer"} for n, _ in layers]})
    for n, draw in layers:
        layer = stack / f"{n}.imagestacklayer"
        write_json(layer, {"info": INFO})
        imgs = []
        for scale, w, h in sizes:
            fn = f"{n.lower()}{'' if scale == 1 else '@%dx' % scale}.png"
            img = draw(w, h)
            (layer / "Content.imageset").mkdir(parents=True, exist_ok=True)
            img.save(layer / "Content.imageset" / fn)
            imgs.append({"filename": fn, "idiom": "tv", "scale": f"{scale}x"})
        write_json(layer / "Content.imageset", {"images": imgs, "info": INFO})


def flat(w, h):
    img = back(w, h).convert("RGBA")
    img.alpha_composite(middle(w, h))
    img.alpha_composite(front(w, h))
    return img.convert("RGB")


def imageset(name, sizes):
    path = BRAND / f"{name}.imageset"
    imgs = []
    path.mkdir(parents=True, exist_ok=True)
    for scale, w, h in sizes:
        fn = f"{name.lower().replace(' ', '-')}{'' if scale == 1 else '@%dx' % scale}.png"
        flat(w, h).save(path / fn)
        imgs.append({"filename": fn, "idiom": "tv", "scale": f"{scale}x"})
    write_json(path, {"images": imgs, "info": INFO})


def main():
    write_json(ASSETS, {"info": INFO})
    write_json(BRAND, {
        "assets": [
            {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
            {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
            {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
            {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
        ],
        "info": INFO,
    })
    imagestack("App Icon", [(1, 400, 240), (2, 800, 480)])
    imagestack("App Icon - App Store", [(1, 1280, 768)])
    imageset("Top Shelf Image", [(1, 1920, 720), (2, 3840, 1440)])
    imageset("Top Shelf Image Wide", [(1, 2320, 720), (2, 4640, 1440)])
    print("wrote", BRAND.relative_to(ROOT.parent))


if __name__ == "__main__":
    main()
