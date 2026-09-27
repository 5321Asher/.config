#!/usr/bin/env python3
"""Observatory's star-chart wallpaper, drawn from a colour theme.

    starchart.py [theme-id] [WxH] [seed]   ->  ~/Pictures/Wallpaper-Themes/_pool/observatory-<theme>-<seed>.png

A polar star chart seen from an observatory dome: blue-black sky with a faint nebula, a few thousand
stars, a brass azimuthal grid (declination circles, hour lines) around an off-centre pole, a
graduated astrolabe ring and a handful of constellations. Written as SVG, rendered by ImageMagick.
Then assign it with `theme pool` (s = the whole setup, or a number key for one theme).
"""

import math
import os
import random
import subprocess
import sys
import tomllib

HERE = os.path.dirname(os.path.realpath(__file__))
POOL = os.path.expanduser("~/Pictures/Wallpaper-Themes/_pool")


def palette(tid):
    with open(f"{HERE}/themes/{tid}.toml", "rb") as f:
        p = tomllib.load(f)["palette"]
    return {
        "bg": p["bg"], "deep": p.get("bgDark", p["bg"]), "brass": p["accent"],
        "bright": p.get("brassBright", p["accent"]), "phosphor": p.get("phosphor", p.get("purple", p["accent"])),
        "star": p.get("starlight", p["fg"]), "signal": p.get("signal", p.get("danger", "#d9534f")),
        "surface": p.get("surface", p["bg"]),
    }


def build(c, w, h, rng):
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
           "<defs>",
           f'<radialGradient id="sky" cx="0.62" cy="0.42" r="0.9">'
           f'<stop offset="0" stop-color="{c["surface"]}"/><stop offset="0.55" stop-color="{c["bg"]}"/>'
           f'<stop offset="1" stop-color="{c["deep"]}"/></radialGradient>',
           '<filter id="neb" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="90"/></filter>',
           '<filter id="glow" x="-200%" y="-200%" width="500%" height="500%"><feGaussianBlur stdDeviation="2.2"/></filter>',
           "</defs>",
           f'<rect width="{w}" height="{h}" fill="url(#sky)"/>']

    # Nebula: a few soft clouds, phosphor and a touch of brass, very faint
    for _ in range(7):
        x, y = rng.uniform(0.1, 0.9) * w, rng.uniform(0.15, 0.85) * h
        rx, ry = rng.uniform(0.12, 0.3) * w, rng.uniform(0.06, 0.16) * h
        col = c["phosphor"] if rng.random() < 0.65 else c["brass"]
        out.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{rx:.0f}" ry="{ry:.0f}" fill="{col}" '
                   f'opacity="{rng.uniform(0.035, 0.07):.3f}" filter="url(#neb)" '
                   f'transform="rotate({rng.uniform(-35, 35):.0f} {x:.0f} {y:.0f})"/>')

    # The chart: pole off to the right, rings out past the screen
    px, py = w * 0.68, h * 0.44
    R = max(w, h) * 0.95
    grid = f'stroke="{c["brass"]}" fill="none"'
    for i, r in enumerate(range(90, int(R), 120)):
        out.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{r}" {grid} stroke-width="{1.2 if i % 3 == 2 else 0.7}" '
                   f'opacity="{0.16 if i % 3 == 2 else 0.08}"/>')
    for k in range(24):
        a = k * math.pi / 12
        x2, y2 = px + R * math.cos(a), py + R * math.sin(a)
        r0 = 90 if k % 6 else 0
        out.append(f'<line x1="{px + r0 * math.cos(a):.0f}" y1="{py + r0 * math.sin(a):.0f}" x2="{x2:.0f}" y2="{y2:.0f}" '
                   f'{grid} stroke-width="{1 if k % 6 == 0 else 0.6}" opacity="{0.14 if k % 6 == 0 else 0.07}"/>')

    # Astrolabe ring: a graduated brass circle with degree ticks and hour numerals
    ar = h * 0.36
    out.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{ar:.0f}" {grid} stroke-width="1.8" opacity="0.5"/>')
    out.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{ar - 14:.0f}" {grid} stroke-width="0.8" opacity="0.22"/>')
    out.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{ar + 30:.0f}" {grid} stroke-width="0.6" opacity="0.14"/>')
    for d in range(0, 360, 2):
        a = math.radians(d)
        long = d % 10 == 0
        r1 = ar - (14 if long else 7)
        out.append(f'<line x1="{px + ar * math.cos(a):.1f}" y1="{py + ar * math.sin(a):.1f}" '
                   f'x2="{px + r1 * math.cos(a):.1f}" y2="{py + r1 * math.sin(a):.1f}" {grid} '
                   f'stroke-width="{1 if long else 0.6}" opacity="{0.42 if long else 0.24}"/>')
    for hr in range(24):
        a = math.radians(hr * 15 - 90)
        x, y = px + (ar + 18) * math.cos(a), py + (ar + 18) * math.sin(a)
        out.append(f'<text x="{x:.1f}" y="{y + 4:.1f}" font-family="Cormorant Garamond" font-size="19" '
                   f'text-anchor="middle" fill="{c["brass"]}" opacity="0.62">{hr:02d}h</text>')

    # Stars: many faint, few bright; a Milky Way band gets extra
    def star(x, y, big=False):
        r = rng.uniform(1.6, 2.6) if big else rng.choice([0.5, 0.6, 0.7, 0.8, 1.0, 1.2])
        o = rng.uniform(0.75, 1) if big else rng.uniform(0.25, 0.85)
        col = c["star"] if rng.random() > 0.12 else (c["phosphor"] if rng.random() < 0.6 else c["bright"])
        if big:
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r * 2.6:.1f}" fill="{col}" opacity="0.35" filter="url(#glow)"/>')
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="{col}" opacity="{o:.2f}"/>')

    for _ in range(int(w * h / 1400)):
        star(rng.uniform(0, w), rng.uniform(0, h))
    for _ in range(int(w * h / 2600)):   # band from lower left to upper right
        t = rng.random()
        off = rng.gauss(0, 0.07) * h
        star(t * w, h * (0.92 - 0.8 * t) + off)

    # Constellations: bright stars joined by thin phosphor lines
    for _ in range(5):
        cx, cy = rng.uniform(0.08, 0.92) * w, rng.uniform(0.12, 0.88) * h
        pts = [(cx, cy)]
        for _ in range(rng.randint(4, 7)):
            x, y = pts[-1]
            ang = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(60, 150)
            pts.append((min(w - 20, max(20, x + d * math.cos(ang))), min(h - 20, max(20, y + d * math.sin(ang)))))
        path = " ".join(f"{'M' if i == 0 else 'L'} {x:.0f} {y:.0f}" for i, (x, y) in enumerate(pts))
        out.append(f'<path d="{path}" stroke="{c["phosphor"]}" stroke-width="0.9" fill="none" opacity="0.32"/>')
        for x, y in pts:
            star(x, y, big=True)

    # One marked target, like a slewed telescope: a small signal-red reticle
    tx, ty = px - ar * 0.55, py + ar * 0.3
    out.append(f'<circle cx="{tx:.0f}" cy="{ty:.0f}" r="16" stroke="{c["signal"]}" fill="none" stroke-width="1" opacity="0.7"/>')
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        out.append(f'<line x1="{tx + dx * 20:.0f}" y1="{ty + dy * 20:.0f}" x2="{tx + dx * 30:.0f}" y2="{ty + dy * 30:.0f}" '
                   f'stroke="{c["signal"]}" stroke-width="1" opacity="0.7"/>')

    out.append("</svg>")
    return "\n".join(out)


def main():
    tid = sys.argv[1] if len(sys.argv) > 1 else "deep-field"
    w, h = map(int, (sys.argv[2] if len(sys.argv) > 2 else "2560x1440").split("x"))
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 7
    svg = build(palette(tid), w, h, random.Random(seed))
    os.makedirs(POOL, exist_ok=True)
    out = f"{POOL}/observatory-{tid}-{seed}.png"
    tmp = f"/tmp/starchart-{os.getpid()}.svg"
    with open(tmp, "w") as f:
        f.write(svg)
    subprocess.run(["magick", "-density", "96", tmp, out], check=True)
    os.unlink(tmp)
    print(out)


if __name__ == "__main__":
    main()
