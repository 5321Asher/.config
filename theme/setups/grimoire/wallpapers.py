#!/usr/bin/env python3
"""Grimoire's pictures, drawn from its colour themes (Pillow only; run with the theme venv):

  ~/.local/share/theme/venv/bin/python ~/.config/theme/setups/grimoire/wallpapers.py [theme ...]

For each theme (all of them by default), into the wallpaper pool, hardlinked into
~/Pictures/Wallpaper-Themes/grimoire/<theme>/:
  grimoire-<theme>-desk.png   the grimoire's cover, filling the screen: tooled leather lit warm from
                              the left (where the candle stands), a gilt frame with corner flourishes,
                              and a great tooled medallion (rings, a band of runes, a heptagram, the
                              planets' signs) in worn gold, faintly glowing at its heart
And the setup's own images (images/<theme>/):
  walker.png      a tall crop of that medallion, for Walker's side panel
  fastfetch.png   an illuminated capital (your initial) for the terminal
"""

import math
import os
import random
import sys
import tomllib

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
LIBRARY = f"{HOME}/Pictures/Wallpaper-Themes"
POOL = f"{LIBRARY}/_pool"
FONTS = f"{HOME}/.local/share/fonts/grimoire"
W, H = 2560, 1440
SS = 2                              # supersampling for the gold work

RUNES = "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ"


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


def radial(size, centre, radius, inner, outer, power=1.6):
    """An L mask: `inner` at the centre falling to `outer` at `radius` (and beyond)."""
    w, h = size
    small = Image.new("L", (w // 8, h // 8))
    px = small.load()
    cx, cy = centre[0] / 8, centre[1] / 8
    r = radius / 8
    for y in range(small.height):
        for x in range(small.width):
            t = min(1.0, math.hypot(x - cx, y - cy) / r) ** power
            px[x, y] = round(inner + (outer - inner) * t)
    return small.resize(size, Image.BICUBIC)


# ---------------------------------------------------------------- the gold work (on a 2x canvas)

def bezier(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def flourish(d, x, y, sx, sy, s, fill, width):
    """A corner flourish at (x, y), arms running along +sx and +sy, `s` long."""
    P = lambda u, v: (x + sx * u * s, y + sy * v * s)
    d.line([P(0, 1), P(0, 0.2)], fill=fill, width=width)
    d.line([P(0.2, 0), P(1, 0)], fill=fill, width=width)
    d.line(bezier(P(0, 0.2), P(0, 0.05), P(0.05, 0), P(0.2, 0)), fill=fill, width=width)
    # curls at the arms' ends
    for a, b in ((P(0.72, 0), (1, 0)), (P(0, 0.72), (0, 1))):
        ux, uy = b
        c = bezier(a, (a[0] + sx * ux * 0.14 * s, a[1] + sy * uy * 0.14 * s),
                   (a[0] + sx * (ux * 0.18 + uy * 0.16) * s, a[1] + sy * (uy * 0.18 + ux * 0.16) * s),
                   (a[0] + sx * (ux * 0.08 + uy * 0.14) * s, a[1] + sy * (uy * 0.08 + ux * 0.14) * s))
        d.line(c, fill=fill, width=width)
    # the diagonal stem and its leaf
    d.line(bezier(P(0.12, 0.12), P(0.3, 0.16), P(0.4, 0.3), P(0.45, 0.45)), fill=fill, width=width)
    leaf = bezier(P(0.45, 0.45), P(0.58, 0.38), P(0.66, 0.5), P(0.56, 0.56)) + bezier(P(0.56, 0.56), P(0.5, 0.66), P(0.38, 0.58), P(0.45, 0.45))
    d.polygon(leaf, fill=fill)
    for u, v in ((0.35, 0.12), (0.12, 0.35)):
        cx, cy = P(u, v)
        r = 0.022 * s
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def medallion(canvas, d, cx, cy, R, gold, faint, runefont, symfont, rng):
    """The great tooled circle."""
    k = SS
    def ring(r, w, c=gold):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=c, width=max(1, round(w * k)))
    ring(R, 3); ring(R - 10 * k, 1.2)
    ring(R - 64 * k, 1.2); ring(R - 72 * k, 2)
    # the rune band
    n = 48
    for i in range(n):
        a = i / n * 2 * math.pi - math.pi / 2
        rr = R - 37 * k
        ch = RUNES[(i * 7) % len(RUNES)]
        g = Image.new("L", (60 * k, 60 * k))
        ImageDraw.Draw(g).text((30 * k, 30 * k), ch, font=runefont, fill=255, anchor="mm")
        g = g.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)
        canvas.paste(Image.new("RGBA", g.size, gold), (round(cx + math.cos(a) * rr - g.width / 2), round(cy + math.sin(a) * rr - g.height / 2)), g)
    # ticks inside the band
    for i in range(144):
        a = i / 144 * 2 * math.pi
        r1, r2 = R - 72 * k, R - (84 if i % 6 == 0 else 78) * k
        d.line([(cx + math.cos(a) * r1, cy + math.sin(a) * r1), (cx + math.cos(a) * r2, cy + math.sin(a) * r2)], fill=gold, width=max(1, k))
    # the heptagram
    Rs = R * 0.62
    pts = [(cx + math.cos(-math.pi / 2 + j * 2 * math.pi / 7) * Rs, cy + math.sin(-math.pi / 2 + j * 2 * math.pi / 7) * Rs) for j in range(7)]
    for j in range(7):
        d.line([pts[j], pts[(j + 3) % 7]], fill=gold, width=round(1.6 * k))
    for j in range(7):
        d.line([pts[j], pts[(j + 2) % 7]], fill=faint, width=max(1, k))
    ring(Rs, 1.4)
    # the seven alchemical principles on the points: the four elements, sulphur, mercury and salt
    planets = "🜂🜄🜁🜃🜍☿🜔"
    for j, (px, py) in enumerate(pts):
        r = 30 * k
        d.ellipse((px - r, py - r, px + r, py + r), fill=(0, 0, 0, 0), outline=gold, width=round(2 * k))
        d.text((px, py + 2 * k), planets[j], font=symfont, fill=gold, anchor="mm")
    # inner rings and a small star
    ring(R * 0.3, 2); ring(R * 0.3 - 8 * k, 1)
    for j in range(8):
        a = j / 8 * 2 * math.pi
        d.line([(cx, cy), (cx + math.cos(a) * R * 0.24, cy + math.sin(a) * R * 0.24)], fill=faint, width=max(1, k))
    ring(R * 0.06, 1.4)
    # sparse dots round the outside
    for i in range(96):
        a = i / 96 * 2 * math.pi
        r0 = R + 26 * k
        s = (3 if i % 12 == 0 else 1.4) * k
        x, y = cx + math.cos(a) * r0, cy + math.sin(a) * r0
        d.ellipse((x - s, y - s, x + s, y + s), fill=gold)


def desk(p, tid, seed=7):
    rng = random.Random(seed)
    light = tomllib.load(open(f"{HERE}/themes/{tid}.toml", "rb")).get("appearance") == "light"
    leather = rgb(p["bg"])
    dark = rgb(p["bgDark"])
    flame = rgb(p.get("flame", "#ffb04a"))
    gold = rgb(p["accent"])
    arcane = rgb(p["purple"])

    # the leather, lit from the candle at the left
    base = Image.new("RGB", (W, H), lerp(leather, dark, 0.35))
    lit = Image.new("RGB", (W, H), lerp(leather, (255, 255, 255), 0.07 if not light else 0.12))
    base = Image.composite(lit, base, radial((W, H), (W * 0.1, H * 0.8), W * 0.9, 255, 0, 1.2))
    warm = Image.new("RGB", (W, H), lerp(leather, flame, 0.4))
    base = Image.composite(warm, base, radial((W, H), (W * 0.02, H * 0.9), W * 0.45, 120 if not light else 70, 0, 1.8))
    # grain: fine pebbling, and the dye taken a little unevenly
    fine = Image.effect_noise((W, H), 48).convert("L").filter(ImageFilter.GaussianBlur(1.1))
    broad = Image.effect_noise((W // 48, H // 48), 30).convert("L").resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(30))
    lum = ImageChops.add(ImageChops.subtract(fine, Image.new("L", (W, H), 128), 1, 128), ImageChops.subtract(broad, Image.new("L", (W, H), 128), 1, 128), 1, -128)
    strength = 0.11 if not light else 0.07
    grain_l = Image.new("RGB", (W, H), (255, 255, 255))
    grain_d = Image.new("RGB", (W, H), (0, 0, 0))
    base = Image.composite(grain_l, base, lum.point(lambda v: round(max(0, v - 128) * 2 * strength)))
    base = Image.composite(grain_d, base, lum.point(lambda v: round(max(0, 128 - v) * 2 * strength * 1.4)))
    base = base.convert("RGBA")

    # the gold work, supersampled
    big = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    goldA = (*gold, 205)
    faintA = (*gold, 90)
    k = SS
    m = 58 * k
    d.rectangle((m, m, W * k - m, H * k - m), outline=goldA, width=round(2.5 * k))
    m2 = m + 12 * k
    d.rectangle((m2, m2, W * k - m2, H * k - m2), outline=faintA, width=round(1 * k))
    for (x, y, sx, sy) in ((m2, m2, 1, 1), (W * k - m2, m2, -1, 1), (m2, H * k - m2, 1, -1), (W * k - m2, H * k - m2, -1, -1)):
        flourish(d, x + sx * 10 * k, y + sy * 10 * k, sx, sy, 250 * k, goldA, round(2.6 * k))
    # lozenges along the frame
    for x in range(int(m2 + 320 * k), int(W * k - m2 - 300 * k), int(120 * k)):
        for y in (m + 6 * k, H * k - m - 6 * k):
            s = 5 * k
            d.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)], fill=faintA)
    runefont = ImageFont.truetype(f"{FONTS}/NotoSansRunic-Regular.ttf", 26 * k)
    symfont = ImageFont.truetype(f"{FONTS}/NotoSansSymbols[wght].ttf", 30 * k)
    cx, cy, R = W * 0.58 * k, H * 0.5 * k, 520 * k
    medallion(big, d, cx, cy, R, goldA, faintA, runefont, symfont, rng)
    goldwork = big.resize((W, H), Image.LANCZOS)

    # worn gold: rub some of it away with low-frequency noise
    wear = Image.effect_noise((W // 16, H // 16), 90).convert("L").resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
    wear = wear.point(lambda v: max(0, min(255, round((v - 60) * 1.6))))
    r, gg, b, a = goldwork.split()
    a = ImageChops.multiply(a, wear.point(lambda v: 110 + v * 145 // 255))
    # the gold is brighter where the candle reaches it
    shine = radial((W, H), (W * 0.1, H * 0.8), W * 1.1, 255, 150, 1.0)
    a = ImageChops.multiply(a, shine)
    goldwork = Image.merge("RGBA", (r, gg, b, a))
    # sunk into the leather: a dark edge under the gold
    shadow = Image.merge("RGBA", (*[Image.new("L", (W, H), 0)] * 3, a.point(lambda v: v * 3 // 5))).filter(ImageFilter.GaussianBlur(1.2))
    base = Image.alpha_composite(base, ImageChops.offset(shadow, 1, 2))
    base = Image.alpha_composite(base, goldwork)

    # a faint arcane glow at the medallion's heart
    glow = Image.new("RGBA", (W, H), (*arcane, 0))
    glow.putalpha(radial((W, H), (W * 0.58, H * 0.5), 320, 70 if not light else 40, 0, 1.4))
    base = Image.alpha_composite(base, glow)
    # motes of gold dust in the candlelight
    dust = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dust)
    for _ in range(220):
        x, y = rng.gauss(W * 0.18, W * 0.2), rng.gauss(H * 0.7, H * 0.25)
        s = rng.uniform(0.6, 2.2)
        dd.ellipse((x - s, y - s, x + s, y + s), fill=(*lerp(gold, flame, rng.random()), rng.randint(40, 150)))
    base = Image.alpha_composite(base, dust.filter(ImageFilter.GaussianBlur(0.6)))
    # vignette
    vig = Image.new("RGBA", (W, H), (*lerp(dark, (0, 0, 0), 0.5), 0))
    vig.putalpha(radial((W, H), (W * 0.45, H * 0.55), W * 0.75, 0, 170 if not light else 90, 2.2))
    base = Image.alpha_composite(base, vig)
    return base.convert("RGB")


def initial(p, letter, px=512):
    """An illuminated capital: the letter in gold leaf on a ground of wax colour, with a diaper of
    lozenges and white filigree, in a double gold frame."""
    k = 2
    S = px * k
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    gold, bright, deep = rgb(p["accent"]), rgb(p.get("goldBright", p["accent"])), rgb(p.get("goldDeep", p["accent"]))
    ground = rgb(p.get("wax", p["accent"]))
    ink = rgb(p.get("ink", "#2f1d14"))
    page = rgb(p.get("parchment", "#e8dcc0"))
    m = 14 * k
    d.rectangle((0, 0, S - 1, S - 1), fill=(*deep, 255))
    d.rectangle((m // 2, m // 2, S - m // 2, S - m // 2), fill=(*bright, 255))
    d.rectangle((m, m, S - m, S - m), fill=(*ground, 255), outline=(*ink, 255), width=3 * k)
    # the diaper
    step = 46 * k
    for y in range(m, S - m + step, step):
        for x in range(m, S - m + step, step):
            dx = step // 2 if (y // step) % 2 else 0
            cx, cy = x + dx, y
            s = step // 2 - 3 * k
            d.polygon([(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], outline=(*lerp(ground, (0, 0, 0), 0.3), 255), width=2 * k)
            d.ellipse((cx - 3 * k, cy - 3 * k, cx + 3 * k, cy + 3 * k), fill=(*lerp(ground, page, 0.55), 255))
    # re-clip the diaper to the ground
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rectangle((m + 3 * k, m + 3 * k, S - m - 3 * k, S - m - 3 * k), fill=255)
    frame = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rectangle((0, 0, S - 1, S - 1), fill=(*deep, 255))
    fd.rectangle((m // 2, m // 2, S - m // 2, S - m // 2), fill=(*bright, 255))
    fd.rectangle((m - k, m - k, S - m + k, S - m + k), outline=(*ink, 255), width=3 * k)
    img = Image.composite(img, frame, mask)
    # the letter: gold leaf with an ink outline and a drop shadow
    font = ImageFont.truetype(f"{FONTS}/UnifrakturMaguntia-Book.ttf", int(S * 0.8))
    lm = Image.new("L", (S, S), 0)
    ImageDraw.Draw(lm).text((S / 2, S / 2 + S * 0.03), letter, font=font, fill=255, anchor="mm")
    outline = lm.filter(ImageFilter.MaxFilter(9))
    shadow = ImageChops.offset(outline, 6 * k, 8 * k).filter(ImageFilter.GaussianBlur(6 * k))
    img = Image.composite(Image.new("RGBA", (S, S), (0, 0, 0, 255)), img, shadow.point(lambda v: v * 3 // 5))
    img = Image.composite(Image.new("RGBA", (S, S), (*ink, 255)), img, outline)
    leaf = Image.new("RGBA", (S, S))
    lp = leaf.load()
    for y in range(S):
        c = lerp(bright, deep, (y / S) ** 1.2)
        for x in range(0, S):
            lp[x, y] = (*c, 255)
    img = Image.composite(leaf, img, lm)
    # a highlight along the letter's upper edges
    hl = ImageChops.subtract(lm, ImageChops.offset(lm, 0, 5 * k)).filter(ImageFilter.GaussianBlur(k))
    img = Image.composite(Image.new("RGBA", (S, S), (255, 255, 240, 255)), img, hl.point(lambda v: v * 2 // 3))
    return img.resize((px, px), Image.LANCZOS)


def main(only):
    themes = sorted(f[:-5] for f in os.listdir(f"{HERE}/themes") if f.endswith(".toml"))
    letter = (os.environ.get("USER") or "G")[:1].upper()
    for tid in themes:
        if only and tid not in only:
            continue
        p = tomllib.load(open(f"{HERE}/themes/{tid}.toml", "rb"))["palette"]
        os.makedirs(POOL, exist_ok=True)
        out = f"{POOL}/grimoire-{tid}-desk.png"
        img = desk(p, tid)
        img.save(out, optimize=True)
        link(out, f"{LIBRARY}/grimoire/{tid}")
        os.makedirs(f"{HERE}/images/{tid}", exist_ok=True)
        # Walker's side panel: a tall slice through the medallion
        side = img.crop((int(W * 0.58 - 330), 60, int(W * 0.58 + 330), H - 60)).resize((440, 880), Image.LANCZOS)
        side.save(f"{HERE}/images/{tid}/walker.png")
        initial(p, letter).save(f"{HERE}/images/{tid}/fastfetch.png")
        print("drew", tid)


if __name__ == "__main__":
    main(sys.argv[1:])
