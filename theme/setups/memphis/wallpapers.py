#!/usr/bin/env python3
"""Memphis's pictures, drawn from its colour schemes (Pillow only; run with the theme venv):

  ~/.local/share/theme/venv/bin/python ~/.config/theme/setups/memphis/wallpapers.py [theme ...]

For each scheme (all of them by default), into the wallpaper pool, hardlinked into
~/Pictures/Wallpaper-Themes/memphis/<scheme>/:
  memphis-<scheme>-plain.png     the plain desktop colour (the scheme's default wallpaper)
  memphis-<scheme>-pattern.png   a Windows 3.1 desktop pattern, in black on the desktop colour
Once, shared by every scheme (memphis/_all/):
  memphis-clouds.png             the Windows 95 sky: soft white clouds on blue
And the setup's own images (images/_default/): walker.png (a strip of that sky, for Walker's side
panel) and fastfetch.png (the four-colour flag and "Memphis 98", for fastfetch in the MS-DOS Prompt).
"""

import math
import os
import random
import sys
import tomllib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
LIBRARY = f"{HOME}/Pictures/Wallpaper-Themes"
POOL = f"{LIBRARY}/_pool"
W, H = 2560, 1440

# 8 x 8 desktop patterns (Windows 3.1's Control Panel → Desktop → Pattern), one per scheme
PATTERNS = {
    "standard": [0x00, 0x50, 0x72, 0x20, 0x00, 0x05, 0x27, 0x02],   # Critters
    "rainy-day": [0x88, 0x54, 0x22, 0x45, 0x88, 0x15, 0x22, 0x51],  # Weave
    "brick": [0xFF, 0x80, 0x80, 0x80, 0xFF, 0x08, 0x08, 0x08],      # Bricks
    "eggplant": [0x02, 0x07, 0x07, 0x02, 0x20, 0x50, 0x50, 0x20],   # Paisley
    "marine": [0x10, 0x28, 0x44, 0x82, 0x44, 0x28, 0x10, 0x00],     # Diamonds
    "wheat": [0x40, 0xC0, 0xC8, 0x78, 0x78, 0x48, 0x00, 0x00],      # Scottie
    "high-contrast": [0x7F, 0x41, 0x41, 0x41, 0x41, 0x41, 0x7F, 0x00],  # Boxes
}
DEFAULT_PATTERN = [0x82, 0x44, 0x39, 0x44, 0x82, 0x01, 0x01, 0x01]  # Quilt


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def link(src, folder):
    os.makedirs(folder, exist_ok=True)
    dst = os.path.join(folder, os.path.basename(src))
    if os.path.lexists(dst):
        os.unlink(dst)
    try:
        os.link(src, dst)
    except OSError:
        os.symlink(src, dst)


def plain(color):
    return Image.new("RGB", (W, H), color)


def pattern(color, bits, ink=(0, 0, 0), scale=3):
    tile = Image.new("RGB", (8 * scale, 8 * scale), color)
    d = ImageDraw.Draw(tile)
    for y, row in enumerate(bits):
        for x in range(8):
            if row & (0x80 >> x):
                d.rectangle([x * scale, y * scale, x * scale + scale - 1, y * scale + scale - 1], fill=ink)
    img = Image.new("RGB", (W, H))
    for y in range(0, H, tile.height):
        for x in range(0, W, tile.width):
            img.paste(tile, (x, y))
    return img


def noise_layer(w, h, cell, rnd):
    """Value noise: random values on a grid, smoothly interpolated (Pillow's bicubic resize)."""
    small = Image.new("L", (w // cell + 3, h // cell + 3))
    small.putdata([rnd.randint(0, 255) for _ in range(small.width * small.height)])
    return small.resize((w + cell * 3, h + cell * 3), Image.BICUBIC).crop((cell, cell, cell + w, cell + h))


def clouds(w=W, h=H, seed=1995):
    """The Windows 95 sky: fractal noise, thresholded softly into white clouds over a blue gradient."""
    rnd = random.Random(seed)
    lw, lh = w // 4, h // 4               # work small, then scale up (soft edges come free)
    acc = [0.0] * (lw * lh)
    total = 0.0
    for octave, cell in enumerate((96, 48, 24, 12, 6)):
        amp = 0.5 ** octave
        total += amp
        for i, v in enumerate(noise_layer(lw, lh, cell, rnd).get_flattened_data()):
            acc[i] += v * amp
    sky_top, sky_bottom = (46, 94, 196), (110, 160, 230)
    out = []
    for i, v in enumerate(acc):
        y = i // lw
        n = v / total / 255                  # 0..1
        c = max(0.0, min(1.0, (n - 0.47) / 0.22))
        c = c * c * (3 - 2 * c)              # smoothstep
        t = y / lh
        sky = tuple(int(a + (b - a) * t) for a, b in zip(sky_top, sky_bottom))
        white = (255, 255, 255)
        shade = 0.85 + 0.15 * min(1.0, c * 1.5)   # cloud bellies a touch grey
        out.append(tuple(int(s + (wv * shade - s) * c) for s, wv in zip(sky, white)))
    img = Image.new("RGB", (lw, lh))
    img.putdata(out)
    return img.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.2))


def flag(size):
    """The Start button's four-colour flag, as chunky pixels, on transparent."""
    px = size // 22
    img = Image.new("RGBA", (22 * px, 18 * px), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def box(x, y, w, h, c):
        d.rectangle([x * px, y * px, (x + w) * px - 1, (y + h) * px - 1], fill=c)

    for x0, y0, c in ((8, 2, "#f03c1e"), (15, 3, "#28b43c"), (8, 10, "#2878f0"), (15, 11, "#f0c81e")):
        for i in range(7):
            bend = 1 if i < 2 or i > 4 else 0
            box(x0 + i, y0 - bend, 1, 7, c)
    for x, y, w in ((0, 3, 2), (3, 3, 3), (0, 6, 1), (2, 6, 4), (1, 11, 2), (4, 11, 2), (0, 14, 3), (4, 14, 2)):
        box(x, y, w, 2, "#c0c0c0")
    return img


def font(names, size):
    for n in names:
        for d in ("/usr/share/fonts", f"{HOME}/.local/share/fonts"):
            for root, _, files in os.walk(d):
                for f in files:
                    if f.lower() == n.lower():
                        return ImageFont.truetype(os.path.join(root, f), size)
    return ImageFont.load_default(size)


def fastfetch_logo(path):
    img = Image.new("RGBA", (440, 300), (0, 0, 0, 0))
    f = flag(220)
    img.alpha_composite(f, ((440 - f.width) // 2, 10))
    d = ImageDraw.Draw(img)
    word, num = "Memphis", "98"
    for size in range(54, 20, -2):          # as big as fits the width
        big = font(["ariblk.ttf", "Arial_Black.ttf", "W95FA.otf"], size)
        small = font(["arial.ttf", "W95FA.otf"], size)
        ww = d.textlength(word, font=big)
        nw = d.textlength(num, font=small)
        if ww + nw + 8 <= 420:
            break
    x = (440 - ww - nw - 8) // 2
    d.text((x, 262), word, font=big, fill="#ffffff", anchor="ls")
    d.text((x + ww + 8, 262), num, font=small, fill="#c0c0c0", anchor="ls")
    img.save(path)


def main(ids):
    setup = HERE
    os.makedirs(POOL, exist_ok=True)
    themes = sorted(f[:-5] for f in os.listdir(f"{setup}/themes") if f.endswith(".toml"))
    for tid in ids or themes:
        with open(f"{setup}/themes/{tid}.toml", "rb") as f:
            t = tomllib.load(f)
        desk = rgb(t["palette"].get("desktop", "#008080"))
        ink = (255, 255, 255) if tid == "high-contrast" else (0, 0, 0)
        for kind, img in (("plain", plain(desk)), ("pattern", pattern(desk, PATTERNS.get(tid, DEFAULT_PATTERN), ink))):
            path = f"{POOL}/memphis-{tid}-{kind}.png"
            img.save(path, optimize=True)
            link(path, f"{LIBRARY}/memphis/{tid}")
            print(path)

    sky = clouds()
    path = f"{POOL}/memphis-clouds.png"
    sky.save(path)
    link(path, f"{LIBRARY}/memphis/_all")
    print(path)

    os.makedirs(f"{setup}/images/_default", exist_ok=True)
    side = sky.crop((W // 2 - 360, 0, W // 2 + 360, H)).resize((400, 800), Image.BICUBIC)
    side.save(f"{setup}/images/_default/walker.png")
    fastfetch_logo(f"{setup}/images/_default/fastfetch.png")
    print("images/_default: walker.png, fastfetch.png")


if __name__ == "__main__":
    main(sys.argv[1:])
