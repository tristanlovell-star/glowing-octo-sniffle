#!/usr/bin/env python3
"""Draws the 1024x1024 app icon (a white bus on Translink-style pink) for iPhone and Watch.

    python3 Tools/make_icons.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

S = 1024
PINK = (228, 99, 164)
DARK = (150, 40, 100)
WHITE = (255, 255, 255)


def draw_icon():
    img = Image.new("RGB", (S, S), PINK)  # App Store icons must not have transparency.
    d = ImageDraw.Draw(img)
    # Subtle vertical gradient.
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=tuple(int(PINK[i] * (1 - t * 0.25) + DARK[i] * t * 0.25) for i in range(3)))
    # Bus body.
    d.rounded_rectangle([262, 190, 762, 780], radius=90, fill=WHITE)
    # Windscreen.
    d.rounded_rectangle([312, 300, 712, 540], radius=40, fill=PINK)
    # Destination sign.
    d.rounded_rectangle([372, 225, 652, 265], radius=20, fill=PINK)
    # Headlights.
    for cx in (350, 674):
        d.ellipse([cx - 38, 610, cx + 38, 686], fill=PINK)
    # Wheels.
    for x0 in (300, 624):
        d.rounded_rectangle([x0, 760, x0 + 100, 850], radius=30, fill=WHITE)
    return img


def main():
    root = Path(__file__).resolve().parent.parent
    icon = draw_icon()
    for rel in ("iOS/App/Assets.xcassets/AppIcon.appiconset", "Watch/App/Assets.xcassets/AppIcon.appiconset"):
        out = root / rel / "AppIcon.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        icon.save(out)
        print("wrote", out.relative_to(root))


if __name__ == "__main__":
    main()
