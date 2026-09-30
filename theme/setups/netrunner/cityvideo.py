#!/usr/bin/env python3
"""Netrunner's animated night city: a seamless looping video wallpaper per profile.

    cityvideo.py [profile ...]        (every profile when none given)
        -> ~/Pictures/Wallpaper-Themes/_pool/netrunner-<profile>-city.mp4 (hardlinked into netrunner/<profile>/)

The still city (skyline.py's generated pixel skyline, every profile), brought to life:
  - rain in two depths: fine far drizzle and longer near streaks, slanting like the stills'
  - lit windows flicker, a few at a time, and neon signs sputter like a failing tube
  - pixel-art flying cars (AVs) cross at different heights and depths, head- and tail-lights glowing
Everything is periodic in the loop length, so the loop is seamless.

Frames are drawn with Pillow (the theme venv) on every core but two and encoded by ffmpeg on the GPU
(NVENC HEVC) when it can, else x264. ~6 MB/s of loop; 20 s at 30 fps by default.
"""

import math
import os
import random
import subprocess
import sys
import tomllib

HERE = os.path.dirname(os.path.realpath(__file__))
VENV = os.path.expanduser("~/.local/share/theme/venv")
try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    py = f"{VENV}/bin/python"
    if sys.executable != py and os.path.exists(py):
        os.execv(py, [py, os.path.realpath(__file__)] + sys.argv[1:])
    raise

sys.path.insert(0, HERE)
import skyline  # noqa: E402

W, H = skyline.W, skyline.H
LIBRARY, POOL = skyline.LIBRARY, skyline.POOL
SECONDS, FPS = 20, 30
TAU = 2 * math.pi


def rgb(h):
    return skyline.rgb(h)


# ---------------------------------------------------------------- the pieces

def car_sprite(body, glow_col, head, tail, scale):
    """A little AV in pixel art (facing right): hull, canopy, under-glow, lights. Returns RGBA with a
    soft glow around the lights, and the sprite's width."""
    art = [
        "......cccccc........",
        "....ccCCCCCCcc......",
        ".bbbbbbbbbbbbbbbbbH.",
        "Tbbbbbbbbbbbbbbbbbbh",
        ".bbbbbbbbbbbbbbbbbb.",
        "...gggggg....gggggg.",
    ]
    cols = {"c": body, "C": tuple(min(255, int(v * 1.6 + 30)) for v in glow_col), "b": body,
            "H": head, "h": head, "T": tail, "g": glow_col}
    pw, ph = len(art[0]), len(art)
    px = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            if ch in cols:
                px.putpixel((x, y), cols[ch] + (255,))
    px = px.resize((pw * scale, ph * scale), Image.NEAREST)
    pad = 30 * scale // 3 + 20
    out = Image.new("RGBA", (px.width + pad * 2 + 120 * scale // 3, px.height + pad * 2), (0, 0, 0, 0))
    ox, oy = pad, pad
    glow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    s = scale
    gd.ellipse([ox + (pw - 1) * s - 6 * s, oy + 2 * s - 5 * s, ox + (pw + 1) * s + 6 * s, oy + 4 * s + 5 * s], fill=head + (160,))
    gd.ellipse([ox - 5 * s, oy + 3 * s - 4 * s, ox + 2 * s + 5 * s, oy + 4 * s + 4 * s], fill=tail + (170,))
    gd.rectangle([ox + 2 * s, oy + 5 * s, ox + (pw - 2) * s, oy + 7 * s], fill=glow_col + (120,))
    # a faint headlight beam ahead
    beam = 120 * s // 3
    gd.polygon([(ox + pw * s, oy + 2 * s), (ox + pw * s + beam, oy - 4 * s), (ox + pw * s + beam, oy + 9 * s)], fill=head + (40,))
    glow = glow.filter(ImageFilter.GaussianBlur(4 * s))
    out = Image.alpha_composite(out, glow)
    out.alpha_composite(px, (ox, oy))
    return out


class Scene:
    def __init__(self, tid):
        with open(f"{HERE}/themes/{tid}.toml", "rb") as f:
            t = tomllib.load(f)
        pal = t["palette"]
        self.tid = tid
        self.frames = SECONDS * FPS
        rnd = random.Random(f"netrunner-city-{tid}")
        red, cyan, yellow = rgb(pal["accent"]), rgb(pal["purple"]), rgb(pal["warn"])

        # ---- the city: generated, with its lights (Circuit too: the user prefers it to the game's picture)
        self.lights = []
        self.base = skyline.skyline(pal, seed=sum(map(ord, tid)) * 97, rain=False, lights=self.lights)
        # the "off" look of every light we'll flicker, cut from the base once
        windows = [l for l in self.lights if l["kind"] == "window"]
        signs = [l for l in self.lights if l["kind"] == "sign"]
        rnd.shuffle(windows)
        self.flicker = []
        for l in windows[:260] + signs[:6]:
            x0, y0, x1, y1 = [int(v) for v in l["box"]]
            x0, y0, x1, y1 = max(0, x0), max(0, y0), min(W, x1 + 1), min(H, y1 + 1)
            if x1 <= x0 or y1 <= y0:
                continue
            if l["kind"] == "window":
                off = Image.new("RGB", (x1 - x0, y1 - y0), tuple(l["body"]))
            else:
                off = self.base.crop((x0, y0, x1, y1)).point(lambda v: int(v * 0.42))
            # when it's off: a few short blinks for a window, a sputter for a sign
            events = []
            if l["kind"] == "window":
                for _ in range(rnd.randint(1, 3)):
                    events.append((rnd.random(), rnd.uniform(0.01, 0.12)))
            else:
                start = rnd.random()
                for k in range(rnd.randint(4, 9)):
                    events.append(((start + k * rnd.uniform(0.004, 0.012)) % 1, rnd.uniform(0.002, 0.008)))
            self.flicker.append((x0, y0, off, events))

        # ---- rain: (x0, y0, length, speed k, alpha, width)
        self.rain = []
        for _ in range(1500):       # far drizzle
            self.rain.append((rnd.uniform(0, W + 400), rnd.uniform(0, H + 60), rnd.uniform(10, 22), rnd.choice((22, 24, 26)), rnd.randint(18, 40), 1))
        for _ in range(260):        # near streaks
            self.rain.append((rnd.uniform(0, W + 400), rnd.uniform(0, H + 120), rnd.uniform(38, 80), rnd.choice((34, 36, 40)), rnd.randint(34, 70), 2))

        # ---- flying cars: (sprite, y, k turns per loop, phase, direction, bob)
        self.cars = []
        body = skyline.mix(rgb(pal["bg"]), (0, 0, 0), 0.3)
        head = skyline.mix((255, 244, 214), yellow, 0.15)
        for i in range(8):
            depth = i / 7                       # 0 far .. 1 near
            scale = 2 if depth < 0.4 else 3 if depth < 0.8 else 5
            glow_col = rnd.choice([cyan, red, cyan, yellow])
            spr = car_sprite(skyline.mix(body, rgb(pal["bg"]), 0.3 * (1 - depth)), glow_col, head, red, scale)
            if depth < 0.4:                     # far ones sit in the haze
                spr.putalpha(spr.getchannel("A").point(lambda v: int(v * 0.55)))
            direction = 1 if rnd.random() < 0.5 else -1
            if direction < 0:
                spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
            y = rnd.uniform(H * (0.12 + 0.1 * depth), H * (0.42 + 0.18 * depth))
            k = 1 if depth < 0.4 else 2 if depth < 0.8 else 3
            self.cars.append((spr, y, k, rnd.random(), direction, rnd.uniform(3, 10)))

    def render(self, n):
        t = n / self.frames
        img = self.base.copy()

        for (x0, y0, off, events) in self.flicker:
            if any((t - s) % 1 < d for s, d in events):
                img.paste(off, (x0, y0))

        for (spr, y, k, ph, direction, bob) in self.cars:
            span = W + spr.width
            p = (ph + k * t) % 1
            x = -spr.width + p * span if direction > 0 else W - p * span
            yy = y + bob * math.sin(TAU * (k * t + ph))
            img.paste(spr, (int(x), int(yy - spr.height / 2)), spr)

        rain = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(rain)
        for (x0, y0, l, k, a, wdt) in self.rain:
            span = H + l + 60
            y = (y0 + k * span * t) % span - l
            x = (x0 - (y + l) * 0.22) % (W + 400) - 200
            d.line([(x, y), (x - l * 0.22, y + l)], fill=(200, 215, 235, a), width=wdt)
        img.paste(rain, (0, 0), rain)
        return img


# ---------------------------------------------------------------- output

SCENE = None


def frame_bytes(n):
    return SCENE.render(n).tobytes()


def encoder():
    enc = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    if "hevc_nvenc" in enc:
        probe = subprocess.run(["ffmpeg", "-hide_banner", "-f", "lavfi", "-i", "color=s=256x256:d=0.1", "-c:v", "hevc_nvenc",
                                "-f", "null", "-"], capture_output=True)
        if probe.returncode == 0:
            return ["-c:v", "hevc_nvenc", "-preset", "p7", "-tune", "hq", "-rc", "vbr", "-cq", "22", "-b:v", "0",
                    "-profile:v", "main", "-tag:v", "hvc1"]
    return ["-c:v", "libx264", "-preset", "slow", "-crf", "19", "-profile:v", "high"]


def make(tid):
    global SCENE
    import multiprocessing as mp
    SCENE = Scene(tid)
    out = f"{POOL}/netrunner-{tid}-city.mp4"
    tmp = out + ".part.mp4"
    ff = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                           "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-"] + encoder()
                          + ["-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", tmp], stdin=subprocess.PIPE)
    workers = max(2, (os.cpu_count() or 4) - 2)
    with mp.get_context("fork").Pool(workers, initializer=os.nice, initargs=(10,)) as pool:
        for i, data in enumerate(pool.imap(frame_bytes, range(SCENE.frames), chunksize=4)):
            ff.stdin.write(data)
            if i % (FPS * 2) == 0:
                print(f"\r{tid}: {i * 100 // SCENE.frames}%", end="", file=sys.stderr, flush=True)
    ff.stdin.close()
    if ff.wait() != 0:
        sys.exit(f"ffmpeg failed for {tid}")
    os.replace(tmp, out)
    skyline.link(out, f"{LIBRARY}/netrunner/{tid}")
    print(f"\r{tid}: done  {out}", file=sys.stderr)
    return out


def main(args):
    if args and args[0] == "--frame":        # a still for checking: --frame <profile> <n> <out.png>
        global SCENE
        SCENE = Scene(args[1])
        SCENE.render(int(args[2])).save(args[3])
        return
    tids = args or sorted(f[:-5] for f in os.listdir(f"{HERE}/themes") if f.endswith(".toml"))
    for tid in tids:
        print(make(tid))


if __name__ == "__main__":
    main(sys.argv[1:])
