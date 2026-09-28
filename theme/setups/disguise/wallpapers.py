#!/usr/bin/env python3
"""Disguise's pictures, drawn from its colour themes (Pillow only; run with the theme venv):

  ~/.local/share/theme/venv/bin/python ~/.config/theme/setups/disguise/wallpapers.py [theme ...]

For each theme (all of them by default), into the wallpaper pool, hardlinked into
~/Pictures/Wallpaper-Themes/disguise/<theme>/:
  disguise-<theme>-bloom.png     a Bloom, Windows 11's folded-silk flower, in the theme's colours
                                 (the theme's default wallpaper)
And the setup's own images (images/<theme>/): walker.png (a tall crop of that bloom, for Walker's
side panel) and fastfetch.png (the four-pane logo, for fastfetch in the terminal).
"""

import math
import os
import random
import sys
import tomllib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
LIBRARY = f"{HOME}/Pictures/Wallpaper-Themes"
POOL = f"{LIBRARY}/_pool"
W, H = 2560, 1440

# Each theme's bloom: the background (top, bottom), the petals (deep, bright) and a glow colour
BLOOMS = {
    "light": dict(bg=("#dbe8f7", "#f4f7fb"), deep="#0a3fb0", bright="#8cc8ff", glow="#bfe0ff", dark=False),
    "dark": dict(bg=("#020a1c", "#0b1f45"), deep="#08278a", bright="#5ab4ff", glow="#1f6fe0", dark=True),
    "glow": dict(bg=("#0a0514", "#1b0d33"), deep="#3d1591", bright="#d7a8ff", glow="#8a4de0", dark=True),
    "sunrise": dict(bg=("#fbe6d4", "#fff6ee"), deep="#b3300c", bright="#ffc07a", glow="#ffd9b0", dark=False),
    "flow": dict(bg=("#021014", "#07262c"), deep="#004f5c", bright="#7ff0dc", glow="#1bb3a0", dark=True),
    "captured-motion": dict(bg=("#12040a", "#2c0914"), deep="#7a0a2c", bright="#ff9cbc", glow="#d0305e", dark=True),
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def link(src, folder):
    os.makedirs(folder, exist_ok=True)
    dst = os.path.join(folder, os.path.basename(src))
    if os.path.lexists(dst):
        os.unlink(dst)
    try:
        os.link(src, dst)
    except OSError:
        os.symlink(src, dst)


def gradient(size, c1, c2, horizontal=True, power=1.0):
    """An RGB gradient from c1 to c2 across (or down) size."""
    w, h = size
    n = w if horizontal else h
    strip = Image.new("RGB", (n, 1) if horizontal else (1, n))
    px = strip.load()
    for i in range(n):
        t = (i / max(1, n - 1)) ** power
        px[(i, 0) if horizontal else (0, i)] = lerp(c1, c2, t)
    return strip.resize(size)


def background(spec):
    top, bottom = rgb(spec["bg"][0]), rgb(spec["bg"][1])
    img = gradient((W, H), top, bottom, horizontal=False)
    # a soft pool of the glow colour behind the flower
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.2, H * 0.05, W * 0.8, H * 0.95), fill=150 if spec["dark"] else 110)
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    return Image.composite(Image.new("RGB", (W, H), rgb(spec["glow"])), img, glow)


def petal_layer(length, width, deep, bright, fold, curl, rng):
    """One folded ribbon petal, pointing right from its base at (0, width): RGBA, local frame.
    The upper half catches the light, the lower half is the underside of the fold."""
    pad = int(width * 0.4)
    lw, lh = int(length + pad * 2), int(width * 2 + pad * 2)
    cy = lh / 2
    steps = 90
    upper, lower, spine = [], [], []
    for i in range(steps + 1):
        t = i / steps
        # the ribbon widens out then comes to a rounded point; it curls up as it goes
        half = width * (math.sin(math.pi * min(1, t * 1.05)) ** 0.7) * (1 - 0.25 * t)
        x = pad + t * length
        bend = curl * width * (t ** 2)
        s = cy - bend
        spine.append((x, s + fold * half * 0.35 * math.sin(math.pi * t)))
        upper.append((x, s - half))
        lower.append((x, s + half * 0.85))
    top_poly = upper + spine[::-1]
    bot_poly = spine + lower[::-1]

    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    for poly, lo, hi, pw in ((bot_poly, lerp(deep, (0, 0, 0), 0.5), lerp(deep, bright, 0.55), 1.4),
                             (top_poly, deep, bright, 0.8)):
        mask = Image.new("L", (lw, lh), 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(1.2))
        fill = gradient((lw, lh), lo, hi, horizontal=True, power=pw)
        # a sheen across the width: brighter along the spine side
        sheen = gradient((lw, lh), (0, 0, 0), (0, 0, 0), horizontal=False)
        fill = ImageChops.add(fill, sheen)
        layer.paste(Image.merge("RGBA", (*fill.split(), mask)), (0, 0), mask)
    # the crease: a thin bright line along the spine
    crease = Image.new("L", (lw, lh), 0)
    ImageDraw.Draw(crease).line(spine[8:-6], fill=160, width=max(2, int(width * 0.03)))
    crease = crease.filter(ImageFilter.GaussianBlur(width * 0.02))
    layer = Image.composite(Image.new("RGBA", (lw, lh), (*bright, 255)), layer,
                            ImageChops.multiply(crease, layer.getchannel("A")))
    return layer, (pad, cy)


def bloom(spec, seed=11):
    rng = random.Random(seed)
    img = background(spec).convert("RGBA")
    deep, bright = rgb(spec["deep"]), rgb(spec["bright"])
    cx, cy = W * 0.5, H * 0.52
    size = H * 0.5
    # petals: (angle°, length, width, fold, curl), back to front
    petals = [
        (200, 1.05, 0.34, 1, -0.6), (235, 1.00, 0.36, -1, 0.5), (160, 0.95, 0.33, 1, 0.7),
        (275, 0.90, 0.32, 1, -0.5), (320, 1.05, 0.36, -1, 0.6), (20, 1.10, 0.37, 1, -0.6),
        (120, 0.95, 0.35, -1, -0.6), (70, 1.00, 0.36, 1, 0.55), (345, 0.80, 0.30, -1, -0.4),
        (180, 0.70, 0.28, -1, 0.5), (250, 0.65, 0.27, 1, -0.4), (95, 0.62, 0.26, -1, 0.4),
    ]
    for angle, ln, wd, fold, curl in petals:
        length, width = size * ln, size * wd
        t = lerp(deep, bright, rng.uniform(0.0, 0.2))
        layer, (bx, by) = petal_layer(length, width, deep, lerp(bright, t, 0.2), fold, curl, rng)
        rot = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
        # rotate(expand) keeps the centre at the image centre: find where the base went
        ox, oy = layer.width / 2, layer.height / 2
        a = math.radians(angle)
        dx, dy = bx - ox, by - oy
        rx, ry = dx * math.cos(a) + dy * math.sin(a), -dx * math.sin(a) + dy * math.cos(a)
        px, py = rot.width / 2 + rx, rot.height / 2 + ry
        pos = (int(cx - px), int(cy - py))
        # the shadow the petal throws on what's under it
        shadow = rot.getchannel("A").filter(ImageFilter.GaussianBlur(size * 0.05))
        shade = Image.new("RGBA", rot.size, (0, 0, 0, 0))
        shade.putalpha(shadow.point(lambda v: v * (0.6 if spec["dark"] else 0.3)))
        img.alpha_composite(shade, (pos[0] + int(size * 0.02), pos[1] + int(size * 0.04)))
        img.alpha_composite(rot, pos)
    # the heart of the flower, bright, and a haze of glow over everything
    core = Image.new("L", (W, H), 0)
    ImageDraw.Draw(core).ellipse((cx - size * 0.16, cy - size * 0.16, cx + size * 0.16, cy + size * 0.16), fill=255)
    core = core.filter(ImageFilter.GaussianBlur(size * 0.12))
    img = Image.composite(Image.new("RGBA", (W, H), (*lerp(bright, (255, 255, 255), 0.5), 255)), img,
                          core.point(lambda v: v * 0.7))
    rgbimg = img.convert("RGB")
    haze = rgbimg.filter(ImageFilter.GaussianBlur(40))
    rgbimg = ImageChops.screen(rgbimg, haze.point(lambda v: v * (0.35 if spec["dark"] else 0.15)))
    return rgbimg


def logo(px=512):
    """The four panes, in Windows 11's blues."""
    img = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    gap = px * 0.04
    pane = (px - gap) / 2
    for i in range(2):
        for j in range(2):
            g = gradient((int(pane), int(pane)), rgb("#2aa6f4"), rgb("#0067c0"), horizontal=False)
            m = Image.new("L", g.size, 0)
            ImageDraw.Draw(m).rounded_rectangle((0, 0, g.width - 1, g.height - 1), radius=px * 0.012, fill=255)
            img.paste(g, (int(j * (pane + gap)), int(i * (pane + gap))), m)
    return img


def main(only):
    themes = sorted(f[:-5] for f in os.listdir(f"{HERE}/themes") if f.endswith(".toml"))
    for tid in themes:
        if only and tid not in only:
            continue
        spec = BLOOMS.get(tid)
        if not spec:
            continue
        with open(f"{HERE}/themes/{tid}.toml", "rb") as f:
            tomllib.load(f)
        pic = bloom(spec)
        out = f"{POOL}/disguise-{tid}-bloom.png"
        pic.save(out, optimize=True)
        link(out, f"{LIBRARY}/disguise/{tid}")
        side = pic.crop((int(W * 0.5 - H * 0.3), 0, int(W * 0.5 + H * 0.3), H)).resize((360, 864))
        os.makedirs(f"{HERE}/images/{tid}", exist_ok=True)
        side.save(f"{HERE}/images/{tid}/walker.png")
        print("drew", out)
    logo().save(f"{HERE}/images/_default/fastfetch.png")


if __name__ == "__main__":
    main(set(sys.argv[1:]))
