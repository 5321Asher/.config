#!/usr/bin/env python3
"""Grimoire's surface textures, as tileable overlays: white where the surface catches the light, black
where it's in shadow, alpha for how much. Quickshell lays them over flat theme colours, so they work
for every colour theme. Written to ~/.config/quickshell/grimoire/assets/:

  leather.png   pebbled grain with fine creases (the bar, the spine, the book covers)
  paper.png     parchment: fibres, blotches, the odd speck (menus, letters, the codex's pages)
  foxing.png    a page's age spots and darkened margins, stretched over a whole page (not tiled)

Run with the theme venv (Pillow): ~/.local/share/theme/venv/bin/python textures.py
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = os.path.expanduser("~/.config/quickshell/grimoire/assets")
N = 512
random.seed(1618)


def noise(size, scale=1):
    """Grey noise, size x size (scale > 1: blockier)."""
    small = max(1, size // scale)
    img = Image.effect_noise((small, small), 64).convert("L")
    return img.resize((size, size), Image.BICUBIC) if scale > 1 else img


def seamless(img, radius):
    """Blur `img` as if it tiled: blur a 3 x 3 tiling and keep the middle."""
    w, h = img.size
    big = Image.new(img.mode, (w * 3, h * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * w, j * h))
    big = big.filter(ImageFilter.GaussianBlur(radius))
    return big.crop((w, h, 2 * w, 2 * h))


def normalise(img, lo=2, hi=98):
    hist = img.histogram()
    total = sum(hist)
    acc, a, b = 0, 0, 255
    for i, c in enumerate(hist):
        acc += c
        if acc < total * lo / 100:
            a = i
        if acc < total * hi / 100:
            b = i
    b = max(b, a + 1)
    return img.point(lambda v: max(0, min(255, round((v - a) * 255 / (b - a)))))


def overlay(lum, strength, dark=(0, 0, 0), light=(255, 255, 255)):
    """Luminance (128 = no change) -> RGBA overlay: `light` / `dark` with alpha by distance from 128."""
    w, h = lum.size
    out = Image.new("RGBA", (w, h))
    px, src = out.load(), lum.load()
    for y in range(h):
        for x in range(w):
            v = src[x, y] - 128
            a = min(255, round(abs(v) * 2 * strength))
            px[x, y] = (*light, a) if v > 0 else (*dark, a)
    return out


def octave(cells, size=N, seed=None, cells_y=None):
    """Smooth tileable value noise: a cells x cells_y grid of random greys, wrapped and upscaled
    (fewer cells one way than the other: fibres)."""
    rnd = random.Random(seed)
    cy = cells_y or cells
    small = Image.new("L", (cells, cy))
    small.putdata([rnd.randint(0, 255) for _ in range(cells * cy)])
    big = Image.new("L", (cells * 3, cy * 3))
    for i in range(3):
        for j in range(3):
            big.paste(small, (i * cells, j * cy))
    big = big.resize((size * 3, size * 3), Image.BICUBIC)
    return big.crop((size, size, 2 * size, 2 * size))


def fbm(cells, octaves, gain=0.5, seed=0):
    img, weight = octave(cells, seed=seed), 1.0
    total = 1.0
    for k in range(1, octaves):
        weight *= gain
        total += weight
        img = Image.blend(img, octave(cells * 2 ** k, seed=seed + k), weight / total)
    return img


def leather():
    # pebbles: small cells, their centres catching light, the seams between them dark
    cells = fbm(96, 2, 0.45, seed=7)
    broad = fbm(12, 3, 0.5, seed=21)
    lum = normalise(ImageChops.subtract(cells, broad, scale=1, offset=128), 1, 99)
    lum = Image.blend(Image.new("L", (N, N), 128), lum, 0.42)
    # creases: short dark wandering lines
    creases = Image.new("L", (N, N), 128)
    d = ImageDraw.Draw(creases)
    for _ in range(140):
        x, y = random.uniform(0, N), random.uniform(0, N)
        ang = random.uniform(0, 6.283)
        pts = [(x, y)]
        for _ in range(random.randint(3, 10)):
            ang += random.uniform(-0.6, 0.6)
            x += 7 * math.cos(ang)
            y += 7 * math.sin(ang)
            pts.append((x, y))
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                d.line([(px + dx, py + dy) for px, py in pts], fill=random.randint(80, 108), width=1)
    creases = seamless(creases, 0.7)
    lum = ImageChops.add(lum, creases, scale=1, offset=-128)
    # a slow mottling, like dye taken unevenly
    mott = Image.blend(Image.new("L", (N, N), 128), normalise(fbm(4, 3, 0.5, seed=33)), 0.16)
    lum = ImageChops.add(lum, mott, scale=1, offset=-128)
    return overlay(lum, 1.0)


def paper():
    # blotches (low frequency), fibres (stretched noise at a few angles), specks
    blot = Image.blend(Image.new("L", (N, N), 128), normalise(fbm(5, 4, 0.55, seed=3)), 0.5)
    # fibres: noise stretched along x, then along y (both tile)
    across = octave(16, seed=100, cells_y=256)
    down = octave(256, seed=101, cells_y=16)
    fibres = Image.blend(across, down, 0.45)
    fibres = Image.blend(Image.new("L", (N, N), 128), normalise(fibres), 0.3)
    lum = ImageChops.add(blot, fibres, scale=1, offset=-128)
    d = ImageDraw.Draw(lum)
    for _ in range(70):
        x, y, r = random.uniform(0, N), random.uniform(0, N), random.uniform(0.4, 1.3)
        d.ellipse((x - r, y - r, x + r, y + r), fill=random.randint(60, 100))
    lum = seamless(lum, 0.4)
    # the shadows are a warm brown (iron-gall and age), not grey
    return overlay(lum, 1.0, dark=(84, 54, 22), light=(255, 251, 238))


def foxing(w=1024, h=1024):
    """A page's age: darker toward the edges, a few soft brown foxing spots (not tiled)."""
    img = Image.new("L", (w, h), 128)
    d = ImageDraw.Draw(img)
    # darkened margins: concentric rectangles
    for i in range(60):
        v = 128 - round((60 - i) ** 1.6 / 60 ** 1.6 * 70)
        d.rectangle((i * 3, i * 3, w - 1 - i * 3, h - 1 - i * 3), outline=v, width=3)
    img = img.filter(ImageFilter.GaussianBlur(18))
    spots = Image.new("L", (w, h), 128)
    ds = ImageDraw.Draw(spots)
    for _ in range(26):
        x, y, r = random.uniform(0, w), random.uniform(0, h), random.uniform(4, 26)
        ds.ellipse((x - r, y - r, x + r, y + r), fill=random.randint(96, 118))
    spots = spots.filter(ImageFilter.GaussianBlur(6))
    lum = ImageChops.add(img, spots, scale=1, offset=-128)
    out = overlay(lum, 0.9)
    # foxing is brown, not black
    r, g, b, a = out.split()
    brown = Image.merge("RGBA", (Image.new("L", (w, h), 70), Image.new("L", (w, h), 40), Image.new("L", (w, h), 12), a))
    return brown


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    leather().save(f"{OUT}/leather.png", optimize=True)
    paper().save(f"{OUT}/paper.png", optimize=True)
    foxing().save(f"{OUT}/foxing.png", optimize=True)
    print("wrote", ", ".join(sorted(os.listdir(OUT))))
