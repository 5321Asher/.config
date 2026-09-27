#!/usr/bin/env python3
"""Observatory's animated star chart: a seamless looping video wallpaper, drawn from a colour theme.

    skyvideo.py [theme-id] [WxH] [seconds] [fps]
        -> ~/Pictures/Wallpaper-Themes/_pool/observatory-<theme>-sky.mp4
    skyvideo.py --all        every Observatory theme

The still star chart (starchart.py), brought to life:
  - the astrolabe ring turns one full revolution per loop, a phosphor sweep circling it
  - the sky rotates slowly about the pole, like a long exposure
  - constellations take turns drawing themselves in, holding, and fading, so the patterns change
  - bright stars twinkle; shooting stars cross now and then
  - the signal-red reticle slews from constellation to constellation like a telescope locking on
The loop is seamless: every motion is periodic in the loop length or finishes before the end, and the
sky's rotation cross-fades back to its start over the last seconds.

Frames are drawn with Pillow (a private venv, ~/.local/share/theme/venv, made on first run) on
every core but two, and encoded by ffmpeg on the GPU (NVENC HEVC) when it can, else x264.
"""

import math
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
VENV = os.path.expanduser("~/.local/share/theme/venv")

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    py = f"{VENV}/bin/python"
    if sys.executable != py:
        if not os.path.exists(py):
            print("making a venv with Pillow in", VENV, file=sys.stderr)
            subprocess.run([sys.executable, "-m", "venv", VENV], check=True)
            subprocess.run([f"{VENV}/bin/pip", "install", "-q", "pillow"], check=True)
        os.execv(py, [py, os.path.realpath(__file__)] + sys.argv[1:])
    raise

sys.path.insert(0, HERE)
import starchart  # noqa: E402  (palette() from the theme file)

POOL = os.path.expanduser("~/Pictures/Wallpaper-Themes/_pool")
SS = 2                                          # supersampling for line art
FONT = subprocess.run(["fc-match", "-f", "%{file}", "Cormorant Garamond:semibold"],
                      capture_output=True, text=True).stdout.strip()


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgba(h, a):
    return rgb(h) + (max(0, min(255, round(a * 255))),)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def ease(t):                                    # in-out cubic
    t = max(0.0, min(1.0, t))
    return 4 * t ** 3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


# ---------------------------------------------------------------- the scene (built once)

class Scene:
    def __init__(self, tid, w, h, seconds, fps, seed=7):
        self.c = starchart.palette(tid)
        self.w, self.h, self.L, self.fps = w, h, seconds, fps
        self.frames = int(seconds * fps)
        self.rng = random.Random(seed)
        self.px, self.py = w * 0.68, h * 0.44          # the pole, as in the stills
        self.ar = h * 0.36                              # astrolabe ring radius
        self.sky_turn = 9.0                             # degrees the sky turns per loop
        self.fade_tail = 6.0                            # seconds of cross-fade at the seam
        self.light = sum(rgb(self.c["bg"])) > 382       # Lunar: dark ink on parchment
        self.base = self.make_base()
        self.make_sky()
        self.ring = self.make_ring()
        self.sweep = self.make_sweep()
        self.make_constellations()
        self.make_twinkles()
        self.make_meteors()
        self.reticle = self.make_reticle()
        self.plan_reticle()

    # -- static background: gradient, nebula, grain, the polar grid
    def make_base(self):
        c, w, h = self.c, self.w, self.h
        sw, sh = w // 5, h // 5
        stops = [(0, rgb(c["surface"])), (0.55, rgb(c["bg"])), (1.0, rgb(c["deep"]))]
        small = Image.new("RGB", (sw, sh))
        px = small.load()
        for y in range(sh):
            for x in range(sw):
                d = math.hypot((x / sw - 0.62) / 0.9, (y / sh - 0.42) / 0.9)
                for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
                    if d <= p1 or p1 == 1.0:
                        px[x, y] = lerp(c0, c1, min(1, (d - p0) / (p1 - p0)))
                        break
        base = small.resize((w, h), Image.BICUBIC).convert("RGBA")

        # nebula: soft clouds, phosphor and a touch of brass
        neb = Image.new("RGBA", (w // 8, h // 8), (0, 0, 0, 0))
        d = ImageDraw.Draw(neb)
        for _ in range(7):
            x, y = self.rng.uniform(0.1, 0.9) * w / 8, self.rng.uniform(0.15, 0.85) * h / 8
            rx, ry = self.rng.uniform(0.12, 0.3) * w / 8, self.rng.uniform(0.06, 0.16) * h / 8
            col = c["phosphor"] if self.rng.random() < 0.65 else c["brass"]
            blob = Image.new("RGBA", neb.size, (0, 0, 0, 0))
            ImageDraw.Draw(blob).ellipse((x - rx, y - ry, x + rx, y + ry),
                                         fill=rgba(col, self.rng.uniform(0.035, 0.07)))
            neb = Image.alpha_composite(neb, blob.rotate(self.rng.uniform(-35, 35), center=(x, y)))
        neb = neb.filter(ImageFilter.GaussianBlur(11)).resize((w, h), Image.BICUBIC)
        base = Image.alpha_composite(base, neb)

        # fine grain, so dark gradients don't band after encoding
        grain = Image.effect_noise((w, h), 10).convert("L")
        tint = (255, 255, 255) if not self.light else (0, 0, 0)
        base = Image.alpha_composite(base, Image.merge("RGBA", [Image.new("L", (w, h), v) for v in tint]
                                                       + [grain.point(lambda v: max(0, (v - 128)) // 24)]))

        # the polar grid: declination circles and hour lines about the pole
        grid = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        g = ImageDraw.Draw(grid)
        R = max(w, h) * 0.95
        for i, r in enumerate(range(90, int(R), 120)):
            strong = i % 3 == 2
            g.ellipse(self.box(self.px, self.py, r, SS), outline=rgba(c["brass"], 0.16 if strong else 0.08),
                      width=round((1.2 if strong else 0.7) * SS))
        for k in range(24):
            a = k * math.pi / 12
            r0 = 90 if k % 6 else 0
            g.line([(SS * (self.px + r0 * math.cos(a)), SS * (self.py + r0 * math.sin(a))),
                    (SS * (self.px + R * math.cos(a)), SS * (self.py + R * math.sin(a)))],
                   fill=rgba(c["brass"], 0.14 if k % 6 == 0 else 0.07), width=round((1 if k % 6 == 0 else 0.6) * SS))
        base = Image.alpha_composite(base, grid.resize((w, h), Image.LANCZOS))
        return base

    @staticmethod
    def box(x, y, r, s=1):
        return (s * (x - r), s * (y - r), s * (x + r), s * (y + r))

    # -- the sky: a big square about the pole that turns (stars + constellation stars)
    def star_sprite(self, r, col, alpha, glow=False):
        key = (round(r * 4), col, round(alpha * 40), glow)
        if key in self._sprites:
            return self._sprites[key]
        k = 8
        size = int(math.ceil((r * (3.2 if glow else 1) + 2) * 2))
        im = Image.new("RGBA", (size * k, size * k), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        cx = size * k / 2
        if glow:
            d.ellipse((cx - r * 2.8 * k, cx - r * 2.8 * k, cx + r * 2.8 * k, cx + r * 2.8 * k), fill=rgba(col, 0.3))
            im = im.filter(ImageFilter.GaussianBlur(r * 1.3 * k))
            d = ImageDraw.Draw(im)
        d.ellipse((cx - r * k, cx - r * k, cx + r * k, cx + r * k), fill=rgba(col, alpha))
        im = im.resize((size, size), Image.LANCZOS)
        self._sprites[key] = im
        return im

    def to_sky(self, x, y):
        """frame coordinates -> sky-square coordinates (at rotation 0)"""
        return x - self.px + self.half, y - self.py + self.half

    def make_sky(self):
        self._sprites = {}
        c, w, h, rng = self.c, self.w, self.h, self.rng
        corners = [(0, 0), (w, 0), (0, h), (w, h)]
        self.half = int(max(math.hypot(x - self.px, y - self.py) for x, y in corners)) + 24
        side = self.half * 2
        sky = Image.new("RGBA", (side, side), (0, 0, 0, 0))

        def colour():
            t = rng.random()
            return c["star"] if t > 0.12 else (c["phosphor"] if rng.random() < 0.6 else c["bright"])

        def stamp(x, y, r, col, alpha, glow=False):
            s = self.star_sprite(r, col, alpha, glow)
            sky.alpha_composite(s, (int(x - s.width / 2), int(y - s.height / 2)))

        for _ in range(int(side * side / 1500)):
            stamp(rng.uniform(0, side), rng.uniform(0, side), rng.choice([0.5, 0.6, 0.7, 0.8, 1.0, 1.2]),
                  colour(), rng.uniform(0.25, 0.85))
        # a Milky Way band from lower left to upper right (in frame terms), extended past the edges
        for _ in range(int(w * h / 2200)):
            t = rng.uniform(-0.25, 1.25)
            x, y = self.to_sky(t * w, h * (0.92 - 0.8 * t) + rng.gauss(0, 0.07) * h)
            stamp(x, y, rng.choice([0.5, 0.6, 0.7, 0.8, 1.0]), colour(), rng.uniform(0.25, 0.8))
        self.sky = sky
        self.stamp = stamp

    # -- the astrolabe ring (turns), and a phosphor sweep that circles it
    def make_ring(self):
        c, ar = self.c, self.ar
        half = int(ar + 70)
        im = Image.new("RGBA", (half * 2 * SS, half * 2 * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        o = half
        d.ellipse(self.box(o, o, ar, SS), outline=rgba(c["brass"], 0.55), width=round(1.8 * SS))
        d.ellipse(self.box(o, o, ar - 14, SS), outline=rgba(c["brass"], 0.24), width=round(0.8 * SS))
        d.ellipse(self.box(o, o, ar + 30, SS), outline=rgba(c["brass"], 0.15), width=round(0.6 * SS))
        for deg in range(0, 360, 2):
            a = math.radians(deg)
            long = deg % 10 == 0
            r1 = ar - (14 if long else 7)
            d.line([(SS * (o + ar * math.cos(a)), SS * (o + ar * math.sin(a))),
                    (SS * (o + r1 * math.cos(a)), SS * (o + r1 * math.sin(a)))],
                   fill=rgba(c["brass"], 0.46 if long else 0.26), width=round((1 if long else 0.6) * SS))
        font = ImageFont.truetype(FONT, 19 * SS) if FONT else ImageFont.load_default()
        for hr in range(24):
            a = math.radians(hr * 15 - 90)
            x, y = o + (ar + 18) * math.cos(a), o + (ar + 18) * math.sin(a)
            d.text((SS * x, SS * y), f"{hr:02d}h", font=font, fill=rgba(c["brass"], 0.66), anchor="mm")
        self.ring_half = half
        return im.resize((half * 2, half * 2), Image.LANCZOS)

    def make_sweep(self):
        """A phosphor arc on the ring with a fading tail, drawn pointing at angle 0 (turns each frame)."""
        c, ar, half = self.c, self.ar, self.ring_half
        im = Image.new("RGBA", (half * 2 * SS, half * 2 * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        o = half
        steps = 60
        for i in range(steps):                          # tail: 50 degrees behind the head
            a0, a1 = -50 + 50 * i / steps, -50 + 50 * (i + 1) / steps + 0.5
            d.arc(self.box(o, o, ar - 7, SS), a0, a1, fill=rgba(c["phosphor"], 0.75 * (i / steps) ** 2), width=round(3 * SS))
        im = im.resize((half * 2, half * 2), Image.LANCZOS)
        glow = im.filter(ImageFilter.GaussianBlur(4))
        return Image.alpha_composite(glow, im)

    # -- constellations: bright stars always in the sky; their lines draw in, hold, fade, in turn
    def make_constellations(self):
        c, w, h, rng = self.c, self.w, self.h, self.rng
        self.consts = []
        n = 7
        usable = self.L - 2 * self.fade_tail - 4
        slot = usable / n
        for i in range(n):
            # somewhere comfortably on screen (away from the ring's centre readouts)
            while True:
                cx, cy = rng.uniform(0.08, 0.92) * w, rng.uniform(0.14, 0.86) * h
                if math.hypot(cx - self.px, cy - self.py) > self.ar * 0.5:
                    break
            pts = [(cx, cy)]
            for _ in range(rng.randint(4, 7)):
                x, y = pts[-1]
                ang = rng.uniform(0, 2 * math.pi)
                dist = rng.uniform(60, 150)
                pts.append((min(w - 30, max(30, x + dist * math.cos(ang))), min(h - 30, max(30, y + dist * math.sin(ang)))))
            sky_pts = [self.to_sky(x, y) for x, y in pts]
            for x, y in sky_pts:
                self.stamp(x, y, rng.uniform(1.6, 2.6), c["star"] if rng.random() > 0.2 else c["bright"],
                           rng.uniform(0.8, 1), glow=True)
            start = self.fade_tail + 2 + i * slot + rng.uniform(0, slot * 0.3)
            draw, fade = 2.8, 2.5
            # every constellation is gone before the seam's cross-fade starts
            hold = max(3.0, min(slot * 1.25, self.L - self.fade_tail - 1 - start - draw - fade))
            self.consts.append({"pts": sky_pts, "start": start, "draw": draw, "hold": hold, "fade": fade})

    def const_alpha(self, k, t):
        """(drawn fraction 0-1, opacity 0-1) of constellation k's lines at time t."""
        s = self.consts[k]
        u = t - s["start"]
        if u < 0 or u > s["draw"] + s["hold"] + s["fade"]:
            return 0.0, 0.0
        drawn = ease(u / s["draw"])
        fade = 1 - smooth((u - s["draw"] - s["hold"]) / s["fade"])
        return drawn, fade

    # -- twinkles: a few dozen bright stars breathing, periodic in the loop
    def make_twinkles(self):
        c, rng = self.c, self.rng
        self.twinkles = []
        for _ in range(60):
            x, y = self.to_sky(rng.uniform(0, self.w), rng.uniform(0, self.h))
            col = c["star"] if rng.random() > 0.3 else rng.choice([c["phosphor"], c["bright"]])
            spr = self.star_sprite(rng.uniform(1.1, 1.9), col, 0.95, glow=True)
            self.twinkles.append((x, y, spr, rng.randint(2, 9), rng.uniform(0, 2 * math.pi)))

    # -- shooting stars at fixed moments, none near the seam
    def make_meteors(self):
        c, w, h, rng = self.c, self.w, self.h, self.rng
        self.meteors = []
        n = 8
        times = sorted(rng.uniform(3, self.L - 4) for _ in range(n))
        head = c["star"]
        for t0 in times:
            ang = math.radians(rng.choice([rng.uniform(20, 55), rng.uniform(125, 160)]))   # heading down-right or down-left
            length = rng.uniform(170, 320)
            speed = rng.uniform(900, 1500)
            dur = rng.uniform(0.55, 0.95)
            x0, y0 = rng.uniform(0.1, 0.9) * w, rng.uniform(0.04, 0.45) * h
            # the streak, drawn once pointing along +x: faint tail to bright head
            L2 = int(length) + 16
            im = Image.new("RGBA", (L2 * SS, 24 * SS), (0, 0, 0, 0))
            d = ImageDraw.Draw(im)
            for i in range(80):
                a0 = i / 80
                d.line([(SS * (8 + length * a0), SS * 12), (SS * (8 + length * (a0 + 1 / 80) + 0.5), SS * 12)],
                       fill=rgba(head, 0.85 * a0 ** 2.2), width=round((0.6 + 1.6 * a0) * SS))
            d.ellipse(self.box(8 + length, 12, 2.4, SS), fill=rgba(head, 1))
            im = im.resize((L2, 24), Image.LANCZOS)
            im = Image.alpha_composite(im.filter(ImageFilter.GaussianBlur(2.2)), im)
            spr = im.rotate(-math.degrees(ang), expand=True, resample=Image.BICUBIC)
            self.meteors.append({"t0": t0, "dur": dur, "x0": x0, "y0": y0, "vx": speed * math.cos(ang),
                                 "vy": speed * math.sin(ang), "spr": spr, "ang": ang, "len": length})

    # -- the reticle and where it points over the loop
    def make_reticle(self):
        col = self.c["signal"]
        size = 72
        im = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        o = size / 2
        d.ellipse(self.box(o, o, 16, SS), outline=rgba(col, 0.8), width=round(1.2 * SS))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            d.line([(SS * (o + dx * 21), SS * (o + dy * 21)), (SS * (o + dx * 31), SS * (o + dy * 31))],
                   fill=rgba(col, 0.8), width=round(1.2 * SS))
        return im.resize((size, size), Image.LANCZOS)

    def plan_reticle(self):
        self.home = (self.px - self.ar * 0.55, self.py + self.ar * 0.3)
        self.stops = []          # (time it starts slewing, constellation index or None for home)
        for k, s in enumerate(self.consts):
            self.stops.append((s["start"] + s["draw"] * 0.6, k))
        self.stops.append((self.L - self.fade_tail - 2.5, None))
        self.slew = 1.4

    # ---------------------------------------------------------------- per frame

    def theta(self, t):
        return self.sky_turn * t / self.L

    def sky_to_frame(self, x, y, deg):
        """sky-square point -> frame point, with the sky turned deg degrees about the pole"""
        a = math.radians(deg)
        dx, dy = x - self.half, y - self.half
        return (self.px + dx * math.cos(a) - dy * math.sin(a), self.py + dx * math.sin(a) + dy * math.cos(a))

    def sky_frame(self, deg):
        """the sky square turned deg degrees (counter-clockwise on screen) and cut to the frame"""
        a = math.radians(deg)
        ca, sa = math.cos(a), math.sin(a)
        # output (u, v) -> input: inverse rotation about the pole, then into sky-square coordinates
        ox, oy = self.px, self.py
        A, B = ca, sa
        D, E = -sa, ca
        C = -ox * ca - oy * sa + ox - self.px + self.half
        F = ox * sa - oy * ca + oy - self.py + self.half
        return self.sky.transform((self.w, self.h), Image.AFFINE, (A, B, C, D, E, F), resample=Image.BILINEAR)

    def place(self, frame, spr, x, y, alpha=1.0):
        """composite a sprite centred at a sub-pixel point, scaled by alpha"""
        if alpha <= 0.003:
            return
        if alpha < 0.999:
            r, g, b, a = spr.split()
            spr = Image.merge("RGBA", (r, g, b, a.point(lambda v: int(v * alpha))))
        ix, iy = math.floor(x - spr.width / 2), math.floor(y - spr.height / 2)
        fx, fy = x - spr.width / 2 - ix, y - spr.height / 2 - iy
        if fx or fy:
            spr = spr.transform((spr.width + 1, spr.height + 1), Image.AFFINE, (1, 0, -fx, 0, 1, -fy),
                                resample=Image.BILINEAR)
        if ix >= self.w or iy >= self.h or ix + spr.width <= 0 or iy + spr.height <= 0:
            return
        frame.alpha_composite(spr, (max(0, ix), max(0, iy)),
                              (max(0, -ix), max(0, -iy), spr.width, spr.height))

    def render(self, n):
        t = n / self.fps
        deg = self.theta(t)
        frame = self.base.copy()

        # the sky, cross-fading back to its start over the last seconds
        sky = self.sky_frame(deg)
        tail = (t - (self.L - self.fade_tail)) / self.fade_tail
        if tail > 0:
            sky = Image.blend(sky, self.sky_frame(deg - self.sky_turn), smooth(tail))
        frame.alpha_composite(sky)

        # twinkles (quiet during the seam so they can't jump)
        quiet = 1 - smooth((t - (self.L - self.fade_tail - 1)) / 1) if t > self.L - self.fade_tail - 1 else smooth(t / 1.5)
        for x, y, spr, k, ph in self.twinkles:
            s = 0.5 + 0.5 * math.sin(2 * math.pi * k * t / self.L + ph)
            fx, fy = self.sky_to_frame(x, y, deg)
            self.place(frame, spr, fx, fy, (s ** 3) * 0.9 * quiet)

        # constellation lines
        for k, s in enumerate(self.consts):
            drawn, op = self.const_alpha(k, t)
            if op <= 0 or drawn <= 0:
                continue
            pts = [self.sky_to_frame(x, y, deg) for x, y in s["pts"]]
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            x0, y0 = int(min(xs)) - 6, int(min(ys)) - 6
            wd, ht = int(max(xs)) - x0 + 8, int(max(ys)) - y0 + 8
            layer = Image.new("RGBA", (wd * SS, ht * SS), (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            segs = len(pts) - 1
            total = drawn * segs
            for i in range(segs):
                part = max(0.0, min(1.0, total - i))
                if part <= 0:
                    break
                (ax, ay), (bx, by) = pts[i], pts[i + 1]
                ex, ey = ax + (bx - ax) * part, ay + (by - ay) * part
                d.line([(SS * (ax - x0), SS * (ay - y0)), (SS * (ex - x0), SS * (ey - y0))],
                       fill=rgba(self.c["phosphor"], 0.5 * op), width=round(1.1 * SS))
            layer = layer.resize((wd, ht), Image.LANCZOS)
            frame.alpha_composite(layer, (max(0, x0), max(0, y0)), (max(0, -x0), max(0, -y0), wd, ht))

        # the ring, one turn per loop, and the sweep circling it six times
        spin = 360 * t / self.L
        ring = self.ring.rotate(-spin, resample=Image.BICUBIC)
        sweep = self.sweep.rotate(-(360 * 6 * t / self.L), resample=Image.BICUBIC)
        rx, ry = int(self.px - self.ring_half), int(self.py - self.ring_half)
        frame.alpha_composite(sweep, (rx, ry))
        frame.alpha_composite(ring, (rx, ry))

        # shooting stars
        for m in self.meteors:
            u = (t - m["t0"]) / m["dur"]
            if 0 <= u <= 1:
                hx = m["x0"] + m["vx"] * (t - m["t0"])
                hy = m["y0"] + m["vy"] * (t - m["t0"])
                # the sprite's centre sits half a streak behind the head
                cx = hx - math.cos(m["ang"]) * m["len"] / 2
                cy = hy - math.sin(m["ang"]) * m["len"] / 2
                self.place(frame, m["spr"], cx, cy, math.sin(math.pi * u) ** 0.7)

        # the reticle: slews between constellations, pulses when it locks, home at the seam
        pos, lock = self.reticle_at(t, deg)
        self.place(frame, self.reticle, pos[0], pos[1], 1.0)
        if lock is not None and 0 <= lock < 0.9:
            r = 16 + 30 * ease(lock / 0.9)
            pulse = Image.new("RGBA", (int(r * 2 + 8) * SS, int(r * 2 + 8) * SS), (0, 0, 0, 0))
            o = r + 4
            ImageDraw.Draw(pulse).ellipse(self.box(o, o, r, SS), outline=rgba(self.c["signal"], 0.7 * (1 - lock / 0.9)),
                                          width=round(1.2 * SS))
            pulse = pulse.resize((int(r * 2 + 8), int(r * 2 + 8)), Image.LANCZOS)
            self.place(frame, pulse, pos[0], pos[1])
        return frame.convert("RGB")

    def target(self, stop, t, deg):
        if stop is None:
            return self.home
        x, y = self.consts[stop]["pts"][0]
        return self.sky_to_frame(x, y, deg)

    def reticle_at(self, t, deg):
        prev, lock = None, None
        cur = None
        for ts, stop in self.stops:
            if t >= ts:
                prev, cur = cur, (ts, stop)
        if cur is None:
            return self.home, None
        ts, stop = cur
        u = (t - ts) / self.slew
        dest = self.target(stop, t, deg)
        if u >= 1:
            return dest, t - ts - self.slew
        src = self.target(prev[1], t, deg) if prev else self.home
        e = ease(u)
        return (src[0] + (dest[0] - src[0]) * e, src[1] + (dest[1] - src[1]) * e), None


# ---------------------------------------------------------------- rendering

SCENE = None


def frame_bytes(n):
    return SCENE.render(n).tobytes()


def encoder():
    enc = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    if "hevc_nvenc" in enc:
        probe = subprocess.run(["ffmpeg", "-hide_banner", "-f", "lavfi", "-i", "color=s=256x256:d=0.1", "-c:v", "hevc_nvenc",
                                "-f", "null", "-"], capture_output=True)
        if probe.returncode == 0:
            return ["-c:v", "hevc_nvenc", "-preset", "p7", "-tune", "hq", "-rc", "vbr", "-cq", "20", "-b:v", "0",
                    "-profile:v", "main", "-tag:v", "hvc1"]
    return ["-c:v", "libx264", "-preset", "slow", "-crf", "18", "-profile:v", "high"]


def make(tid, w, h, seconds, fps):
    global SCENE
    import multiprocessing as mp
    SCENE = Scene(tid, w, h, seconds, fps)
    out = f"{POOL}/observatory-{tid}-sky.mp4"
    tmp = out + ".part.mp4"
    os.makedirs(POOL, exist_ok=True)
    ff = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                           "-s", f"{w}x{h}", "-r", str(fps), "-i", "-"] + encoder()
                          + ["-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", tmp], stdin=subprocess.PIPE)
    workers = max(2, (os.cpu_count() or 4) - 2)
    ctx = mp.get_context("fork")
    with ctx.Pool(workers, initializer=os.nice, initargs=(10,)) as pool:
        for i, data in enumerate(pool.imap(frame_bytes, range(SCENE.frames), chunksize=4)):
            ff.stdin.write(data)
            if i % (fps * 10) == 0:
                print(f"\r{tid}: {i * 100 // SCENE.frames}%", end="", file=sys.stderr, flush=True)
    ff.stdin.close()
    if ff.wait() != 0:
        sys.exit(f"ffmpeg failed for {tid}")
    os.replace(tmp, out)
    print(f"\r{tid}: done  {out}", file=sys.stderr)
    return out


def main():
    args = sys.argv[1:]
    if args and args[0] == "--all":
        tids = sorted(f[:-5] for f in os.listdir(f"{HERE}/themes") if f.endswith(".toml"))
        args = args[1:]
    else:
        tids = [args.pop(0) if args else "deep-field"]
    w, h = map(int, (args[0] if args else "2560x1440").split("x"))
    seconds = float(args[1]) if len(args) > 1 else 120
    fps = int(args[2]) if len(args) > 2 else 30
    for tid in tids:
        print(make(tid, w, h, seconds, fps))


if __name__ == "__main__":
    main()
