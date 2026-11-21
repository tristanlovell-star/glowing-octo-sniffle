#!/usr/bin/env python3
"""Draws Spotter's 1024x1024 app icon: a white dumbbell on an orange gradient.

    python3 Tools/make_icon.py          # run from the Spotter folder
"""
from pathlib import Path
from PIL import Image, ImageDraw

S = 1024
TOP = (255, 159, 10)
BOTTOM = (232, 84, 20)
WHITE = (255, 255, 255)


def main():
    img = Image.new("RGB", (S, S), TOP)  # App Store icons must not have transparency.
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=tuple(int(TOP[i] * (1 - t) + BOTTOM[i] * t) for i in range(3)))
    # Draw the dumbbell flat, then rotate it for a bit of energy.
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(layer)
    cy = S // 2
    g.rounded_rectangle([300, cy - 34, 724, cy + 34], radius=30, fill=WHITE)          # handle
    for x0, h in ((232, 190), (150, 130)):                                           # left plates
        g.rounded_rectangle([x0, cy - h, x0 + 70, cy + h], radius=30, fill=WHITE)
    for x0, h in ((722, 190), (804, 130)):                                           # right plates
        g.rounded_rectangle([x0, cy - h, x0 + 70, cy + h], radius=30, fill=WHITE)
    layer = layer.rotate(35, resample=Image.BICUBIC)
    img.paste(layer, (0, 0), layer)
    out = Path(__file__).resolve().parent.parent / "App" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
