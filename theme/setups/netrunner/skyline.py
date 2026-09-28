#!/usr/bin/env python3
"""Netrunner's pictures (Pillow only; run with the theme venv):

  ~/.local/share/theme/venv/bin/python ~/.config/theme/setups/netrunner/skyline.py [profile ...]

For each profile (all by default), a night-city skyline in its colours, into the wallpaper pool and
hardlinked into ~/Pictures/Wallpaper-Themes/netrunner/<profile>/: netrunner-<profile>-skyline.png.
Layers of towers fading into haze, lit windows, vertical neon signs (katakana), glow, a rain veil
and faint scanlines. Circuit's default wallpaper is the night city from the reference picture
(netrunner-nightcity.png, made once from --reference <file>).
Also the setup's images/_default/: walker.png (a tall strip of the Circuit skyline) and fastfetch.png.
"""

import os
import random
import sys
import tomllib

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
LIBRARY = f"{HOME}/Pictures/Wallpaper-Themes"
POOL = f"{LIBRARY}/_pool"
W, H = 2560, 1440
SIGNS = ["ネオン", "サイバー", "データ", "接続中", "防壁", "夜市", "電脳", "警告", "ホテル", "ラーメン", "酒", "薬", "未来", "信号"]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def link(src, folder):
    os.makedirs(folder, exist_ok=True)
    dst = os.path.join(folder, os.path.basename(src))
    if os.path.lexists(dst):
        os.unlink(dst)
    try:
        os.link(src, dst)
    except OSError:
        os.symlink(src, dst)


def font(names, size):
    for n in names:
        for d in ("/usr/share/fonts", f"{HOME}/.local/share/fonts"):
            for root, _, files in os.walk(d):
                for f in files:
                    if f.lower() == n.lower():
                        try:
                            return ImageFont.truetype(os.path.join(root, f), size)
                        except OSError:
                            pass
    return None


def skyline(pal, seed=2077):
    rnd = random.Random(seed)
    bg, red, cyan, yellow = rgb(pal["bg"]), rgb(pal["accent"]), rgb(pal["purple"]), rgb(pal["warn"])
    white = (225, 235, 245)

    # sky: black at the top, smog lit from below by the city (accent, then cyan) at the horizon
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    top = mix(bg, (0, 0, 0), 0.5)
    low = mix(mix(bg, red, 0.35), cyan, 0.12)
    for y in range(H):
        t = min(1, (y / (H * 0.75)) ** 2.2)
        d.line([(0, y), (W, y)], fill=mix(top, low, t) + (255,))
    # a wide bloom over the centre of the city
    bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(bloom).ellipse([W * 0.15, H * 0.35, W * 0.85, H * 1.2], fill=mix(red, cyan, 0.3) + (70,))
    img = Image.alpha_composite(img, bloom.filter(ImageFilter.GaussianBlur(160)))

    jp = font(["NotoSansCJK-Bold.ttc", "NotoSansCJKjp-Bold.otf", "NotoSansCJK-Regular.ttc"], 30)
    horizon = int(H * 0.9)
    layers = [  # count-ish, height range (share of H), haze (0 near .. 1 far), window chance
        (0.3, 0.68, 0.72, 0.10), (0.22, 0.55, 0.5, 0.12), (0.12, 0.4, 0.28, 0.14), (0.05, 0.22, 0.0, 0.12)]
    for li, (hmin, hmax, haze, lit_p) in enumerate(layers):
        tower = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        td, gd = ImageDraw.Draw(tower), ImageDraw.Draw(glow)
        body = mix(mix(bg, (0, 0, 0), 0.55), low, haze * 0.65) + (255,)
        base = horizon + li * int(H * 0.035)
        x = -rnd.randint(0, 150)
        while x < W:
            w = int(rnd.uniform(70, 190) * (1 + li * 0.45))
            h = int(H * rnd.uniform(hmin, hmax) * (1.25 if rnd.random() < 0.08 else 1))
            x0, x1, y0 = x, x + w, base - h
            td.rectangle([x0, y0, x1, H], fill=body)
            if rnd.random() < 0.45:          # a stepped crown / spire
                cw = int(w * rnd.uniform(0.25, 0.55)); cx = x0 + (w - cw) // 2
                ch = rnd.randint(30, 120)
                td.rectangle([cx, y0 - ch, cx + cw, y0], fill=body)
                if rnd.random() < 0.5:
                    td.rectangle([cx + cw // 2 - 2, y0 - ch - rnd.randint(40, 160), cx + cw // 2 + 2, y0 - ch], fill=body)
                    gd.ellipse([cx + cw // 2 - 6, y0 - ch - 170, cx + cw // 2 + 6, y0 - ch - 158], fill=red + (255,))
            # windows, in lit floors
            step = 9 + li * 3
            for wy in range(y0 + 10, base, step):
                if rnd.random() < 0.35:
                    continue
                for wx in range(x0 + 6, x1 - 6, step):
                    if rnd.random() < lit_p * (2.2 + li * 0.6):
                        c = rnd.choice([white, cyan, cyan, yellow, red])
                        c = mix(c, body[:3], haze * 0.75)
                        td.rectangle([wx, wy, wx + 2 + li, wy + 1 + li // 2], fill=c + (255,))
            # rooftop edge in neon on some near towers
            if li >= 2 and rnd.random() < 0.35:
                c = rnd.choice([cyan, red])
                td.line([(x0, y0), (x1, y0)], fill=c + (255,), width=2)
                gd.line([(x0, y0), (x1, y0)], fill=c + (200,), width=8)
            # vertical neon signs with katakana
            if li >= 1 and rnd.random() < 0.4 + li * 0.1:
                c = rnd.choice([red, cyan, red, yellow])
                sw = 22 + li * 6
                sx = x0 + rnd.randint(6, max(7, w - sw - 6))
                sy = y0 + rnd.randint(30, max(31, h // 3))
                sh = rnd.randint(120, 300)
                td.rectangle([sx, sy, sx + sw, sy + sh], fill=mix(c, (0, 0, 0), 0.7) + (255,), outline=c + (255,), width=2)
                gd.rectangle([sx - 4, sy - 4, sx + sw + 4, sy + sh + 4], fill=c + (170,))
                if jp:
                    for i, ch in enumerate(rnd.choice(SIGNS)):
                        td.text((sx + sw // 2, sy + 22 + i * 32), ch, font=jp, fill=mix(c, (255, 255, 255), 0.45) + (255,), anchor="mm")
            # a billboard on the nearest towers
            if li == 3 and rnd.random() < 0.25:
                bw, bh = int(w * 0.8), rnd.randint(110, 200)
                bx, by = x0 + (w - bw) // 2, y0 + rnd.randint(60, max(61, h // 2))
                c1, c2 = rnd.sample([red, cyan, yellow], 2)
                for k in range(bh):
                    td.line([(bx, by + k), (bx + bw, by + k)], fill=mix(c1, c2, k / bh) + (230,))
                for k in range(by, by + bh, 4):
                    td.line([(bx, k), (bx + bw, k)], fill=(0, 0, 0, 80))
                gd.rectangle([bx - 10, by - 10, bx + bw + 10, by + bh + 10], fill=mix(c1, c2, 0.5) + (150,))
            x += w + rnd.randint(-15, 25)
        img = Image.alpha_composite(img, tower)
        # neon light spills over everything (added, like light does)
        for radius, gain in ((42, 0.9), (10, 0.8)):
            g = glow.filter(ImageFilter.GaussianBlur(radius))
            lit = Image.new("RGB", (W, H))
            lit.paste(g.convert("RGB"), mask=g.getchannel("A").point(lambda v: int(v * gain)))
            img = Image.merge("RGBA", (*ImageChops.add(img.convert("RGB"), lit).split(), img.getchannel("A")))
        # haze between this layer and the next
        if li < 3:
            fog = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            fd = ImageDraw.Draw(fog)
            for y in range(int(H * 0.35), H):
                a = int(55 * ((y - H * 0.35) / (H * 0.65)))
                fd.line([(0, y), (W, y)], fill=low + (a,))
            img = Image.alpha_composite(img, fog)

    # rain
    rain = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rain)
    for _ in range(3000):
        x, y, l = rnd.randint(-100, W), rnd.randint(-50, H), rnd.randint(14, 44)
        rd.line([(x, y), (x - l * 0.22, y + l)], fill=(200, 215, 235, rnd.randint(14, 42)), width=1)
    img = Image.alpha_composite(img, rain)
    # scanlines, barely
    lines = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for y in range(0, H, 3):
        ld.line([(0, y), (W, y)], fill=(0, 0, 0, 20))
    img = Image.alpha_composite(img, lines)
    return img.convert("RGB")


def reference(path):
    """The night city from the first reference picture, without its bar, filling 2560 x 1440."""
    src = Image.open(path).convert("RGB")
    w, h = src.size
    src = src.crop((0, 46, w, h))                       # the reference's own bar
    w, h = src.size
    target = W / H
    if w / h > target:
        nw = int(h * target)
        src = src.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / target)
        src = src.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return src.resize((W, H), Image.LANCZOS)


def fastfetch_logo(pal, path):
    """A red chamfered plate with NETRUNNER in display type and a cyan katakana line."""
    img = Image.new("RGBA", (560, 300), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    red, cyan = rgb(pal["accent"]), rgb(pal["purple"])
    d.polygon([(0, 0), (520, 0), (560, 40), (560, 300), (40, 300), (0, 260)], outline=red + (255,), width=4)
    d.rectangle([28, 30, 160, 44], fill=red + (255,))
    big = font(["ChakraPetch-Bold.ttf"], 74)
    jp = font(["NotoSansCJK-Bold.ttc", "NotoSansCJK-Regular.ttc"], 34)
    if big:
        d.text((30, 70), "NET", font=big, fill=(242, 246, 248, 255))
        d.text((30, 150), "RUNNER", font=big, fill=red + (255,))
    if jp:
        d.text((34, 240), "ネットランナー", font=jp, fill=cyan + (255,))
    img.save(path)


def main(args):
    ref = None
    if "--reference" in args:
        i = args.index("--reference")
        ref = args[i + 1]
        args = args[:i] + args[i + 2:]
    os.makedirs(POOL, exist_ok=True)
    if ref:
        out = f"{POOL}/netrunner-nightcity.png"
        reference(ref).save(out)
        link(out, f"{LIBRARY}/netrunner/circuit")
        link(out, f"{LIBRARY}/netrunner/_all")
        print(out)
    themes = sorted(f[:-5] for f in os.listdir(f"{HERE}/themes") if f.endswith(".toml"))
    for tid in args or themes:
        with open(f"{HERE}/themes/{tid}.toml", "rb") as f:
            pal = tomllib.load(f)["palette"]
        out = f"{POOL}/netrunner-{tid}-skyline.png"
        skyline(pal, seed=sum(map(ord, tid)) * 97).save(out, optimize=True)
        link(out, f"{LIBRARY}/netrunner/{tid}")
        print(out)
    with open(f"{HERE}/themes/circuit.toml", "rb") as f:
        pal = tomllib.load(f)["palette"]
    os.makedirs(f"{HERE}/images/_default", exist_ok=True)
    side = (Image.open(f"{POOL}/netrunner-nightcity.png") if os.path.exists(f"{POOL}/netrunner-nightcity.png")
            else skyline(pal)).convert("RGB")
    side.crop((W // 2 - 300, 200, W // 2 + 300, 1400)).resize((400, 800), Image.LANCZOS).save(f"{HERE}/images/_default/walker.png")
    fastfetch_logo(pal, f"{HERE}/images/_default/fastfetch.png")
    print("images/_default: walker.png, fastfetch.png")


if __name__ == "__main__":
    main(sys.argv[1:])
