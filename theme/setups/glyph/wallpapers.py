#!/usr/bin/env python3
"""Glyph's wallpapers, drawn from the themes (Pillow, in ~/.local/share/theme/venv):

  glyph-<theme>-dots.png    the reference's home: a fine grid of dots, and the halftone orb (equal
                            dots whose brightness follows a radial gradient) low on the right
  glyph-<theme>-matrix.png  a big ring of LED dots, one lit red, round a halftone sphere
  glyph-<theme>-grid.png    the grid alone

into ~/Pictures/Wallpaper-Themes/_pool/, hardlinked into glyph/<theme>/; plus each theme's Walker
side picture (images/<theme>/walker.png). Run: ~/.local/share/theme/venv/bin/python wallpapers.py
"""

import math
import os
import tomllib
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
POOL = Path.home() / "Pictures/Wallpaper-Themes/_pool"
SETS = Path.home() / "Pictures/Wallpaper-Themes/glyph"
W, H = 2560, 1440
SS = 2                                  # supersampling, for round dots


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def canvas(bg, w=W, h=H):
    return Image.new("RGB", (w * SS, h * SS), bg)


def dot(d, x, y, r, c):
    d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=c)


def grid(d, p, w=W, h=H, s=1.0):
    step = 32 * s
    for j in range(int(h / step) + 1):
        for i in range(int(w / step) + 1):
            dot(d, i * step + step / 2, j * step + step / 2, 1.5 * s, p["s2"])


def orb(d, p, cx, cy, R, s=1.0, strength=0.24, focus=(-0.36, -0.4)):
    """Equal dots on a 14-px grid inside a circle; brightness from a radial gradient off-centre."""
    pitch = 14 * s
    fx, fy = cx + focus[0] * R, cy + focus[1] * R
    reach = R * 1.33
    for j in range(int((cy - R) // pitch), int((cy + R) // pitch) + 1):
        for i in range(int((cx - R) // pitch), int((cx + R) // pitch) + 1):
            x, y = (i + 0.5) * pitch, (j + 0.5) * pitch
            if math.hypot(x - cx, y - cy) > R:
                continue
            t = max(0.0, 1 - math.hypot(x - fx, y - fy) / reach)
            if t <= 0.02:
                continue
            dot(d, x, y, pitch * 0.3, mix(p["bg"], p["fg"], strength * t))


def finish(img, w=W, h=H):
    return img.resize((w, h), Image.LANCZOS)


def dots(p):
    img = canvas(p["bg"])
    d = ImageDraw.Draw(img)
    s = H / 1080
    grid(d, p, s=s)
    orb(d, p, W - 720 * s + 550 * s, H - 580 * s + 550 * s, 550 * s, s)
    return finish(img)


def matrix(p):
    img = canvas(p["bg"])
    d = ImageDraw.Draw(img)
    s = H / 1080
    grid(d, p, s=s)
    cx, cy, R = W * 0.62, H * 0.5, H * 0.36
    orb(d, p, cx, cy, R * 0.8, s, strength=0.32, focus=(-0.3, -0.35))
    n = 72
    for k in range(n):
        a = 2 * math.pi * k / n - math.pi / 2
        x, y = cx + R * math.cos(a), cy + R * math.sin(a)
        c = p["red"] if k == 9 else mix(p["bg"], p["fg"], 0.5 if k < 9 else 0.16)
        dot(d, x, y, 5.5 * s if k == 9 else 4 * s, c)
    return finish(img)


def plain(p):
    img = canvas(p["bg"])
    d = ImageDraw.Draw(img)
    grid(d, p, s=H / 1080)
    return finish(img)


def side(p):
    w, h = 600, 900
    img = canvas(p["bg"], w, h)
    d = ImageDraw.Draw(img)
    grid(d, p, w, h, s=0.9)
    orb(d, p, w * 0.5, h * 0.55, w * 0.55, 0.9, strength=0.4)
    return finish(img, w, h)


def main():
    POOL.mkdir(parents=True, exist_ok=True)
    for f in sorted((HERE / "themes").glob("*.toml")):
        theme = tomllib.loads(f.read_text())
        pal = theme["palette"]
        p = {k: rgb(pal[k]) for k in ("bg", "s1", "s2", "s3", "fg", "red")}
        tid = f.stem
        (SETS / tid).mkdir(parents=True, exist_ok=True)
        for kind, fn in (("dots", dots), ("matrix", matrix), ("grid", plain)):
            name = f"glyph-{tid}-{kind}.png"
            fn(p).save(POOL / name, optimize=True)
            link = SETS / tid / name
            if link.exists():
                link.unlink()
            os.link(POOL / name, link)
            print(name)
        (HERE / "images" / tid).mkdir(parents=True, exist_ok=True)
        side(p).save(HERE / "images" / tid / "walker.png")


if __name__ == "__main__":
    main()
