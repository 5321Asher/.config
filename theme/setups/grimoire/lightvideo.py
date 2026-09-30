#!/usr/bin/env python3
"""Grimoire's animated wallpaper: light through a tower's stained-glass window, falling through
incense smoke in a dark reading room. A seamless looping video per theme.

    lightvideo.py [theme ...]                 (every theme when none given)
        -> ~/Pictures/Wallpaper-Themes/_pool/grimoire-<theme>-light.mp4 (hardlinked into grimoire/<theme>/)
    lightvideo.py --frame <theme> <sec> <out.png>     one still, for checking

The window itself is off-screen, above the top-right corner (so the top bar and the left spine sit
over the quiet dark): only its light is seen, a fan of shafts split by the mullions and tinted by
the panes, made visible by smoke rising slowly from below and by dust motes that glint as they
drift through the beams. Each theme brings its own light and glass (oxblood: gold sun through ruby
and violet; nightshade: moonlight and a few witch-lights; verdigris: green glass and fireflies;
ember: fire-light and rising embers; vellum: clear morning daylight).

Rendered on the GPU: one GLSL fragment shader (moderngl on a headless EGL context, in the theme
venv), frames piped to ffmpeg (NVENC HEVC when it can, else x264). The smoke's noise is periodic in
height and in time and every mote/spark moves on whole cycles, so the loop is seamless.
"""

import math
import os
import subprocess
import sys
import tomllib

HERE = os.path.dirname(os.path.realpath(__file__))
VENV = os.path.expanduser("~/.local/share/theme/venv")
try:
    import moderngl
    import numpy as np  # noqa: F401  (moderngl's buffers)
except ImportError:
    py = f"{VENV}/bin/python"
    if sys.executable != py and os.path.exists(py):
        os.execv(py, [py, os.path.realpath(__file__)] + sys.argv[1:])
    sys.exit(f"needs moderngl + numpy: {VENV}/bin/pip install moderngl numpy")

W, H = 2560, 1440
SECONDS, FPS = 60, 30
HOME = os.path.expanduser("~")
LIBRARY = f"{HOME}/Pictures/Wallpaper-Themes"
POOL = f"{LIBRARY}/_pool"


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


# Per theme: the light, the glass (six panes across the window, as palette keys or hex), how much
# light, and the sparks (kind: 0 none, 1 rising embers, 2 wandering lights, 3 blinking fireflies).
LOOKS = {
    "oxblood":    dict(light="#ffd9a0", panes=["light", "light", "rubric", "light", "light", "purple"],
                       glass=0.55, power=1.0, smoke=1.0, sparks=(0, 0, "flame")),
    "nightshade": dict(light="#b8cff5", panes=["light", "light", "purple", "light", "light", "rubric"],
                       glass=0.5, power=0.85, smoke=1.0, sparks=(2, 7, "flame")),
    "verdigris":  dict(light="#f0e2b0", panes=["light", "light", "purple", "light", "light", "green"],
                       glass=0.55, power=0.95, smoke=0.95, sparks=(3, 26, "green")),
    "ember":      dict(light="#ffb070", panes=["light", "light", "danger", "light", "light", "flame"],
                       glass=0.5, power=1.05, smoke=1.15, sparks=(1, 70, "flame")),
    "vellum":     dict(light="#fff6e2", panes=["light", "light", "goldBright", "light", "light", "purple"],
                       glass=0.35, power=0.8, smoke=0.8, sparks=(0, 0, "flame")),
}

VERT = """
#version 330
in vec2 pos;
void main() { gl_Position = vec4(pos, 0.0, 1.0); }
"""

FRAG = """
#version 330
out vec4 frag;
uniform vec2 uRes;
uniform float uT;            // loop phase 0..1
uniform float uLight;        // 1 for a light theme
uniform vec3 uBg, uBgDark, uLightCol, uSmokeCol, uSparkCol;
uniform vec3 uPane[6];
uniform float uPower, uSmoke;
uniform int uSparkKind, uSparkCount;

const float TAU = 6.28318530718;

// ---- noise: gradient noise whose lattice repeats with period `per` (per axis), so fbm can loop
vec3 hash3(vec3 p) {
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
float gnoise(vec3 x, vec3 per) {
    vec3 i = floor(x), f = fract(x);
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    #define G(o) dot(hash3(mod(i + o, per)), f - o)
    return mix(mix(mix(G(vec3(0,0,0)), G(vec3(1,0,0)), u.x), mix(G(vec3(0,1,0)), G(vec3(1,1,0)), u.x), u.y),
               mix(mix(G(vec3(0,0,1)), G(vec3(1,0,1)), u.x), mix(G(vec3(0,1,1)), G(vec3(1,1,1)), u.x), u.y), u.z);
}
float fbm(vec3 x, vec3 per) {
    float a = 0.5, s = 0.0;
    for (int k = 0; k < 6; k++) {
        s += a * gnoise(x, per);
        x *= 2.0; per *= 2.0; a *= 0.5;
    }
    return s;
}
float h1(float n) { return fract(sin(n * 91.3458) * 47453.5453); }

// ---- the window: four tall lights across the fan (u in 0..1), stone mullions between; each light
// throws finer rays (the glass isn't even) and carries its pane colours faintly
float n1(float x) { float i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h1(i), h1(i + 1.0), f); }
vec3 window(float u, float soft) {
    if (u < -0.1 || u > 1.1) return vec3(0.0);
    vec3 c = vec3(0.0);
    for (int k = 0; k < 4; k++) {
        float a = float(k) / 4.0 + 0.014, b = float(k + 1) / 4.0 - 0.014;
        float m = smoothstep(a - soft, a + soft, u) * (1.0 - smoothstep(b - soft, b + soft, u));
        float lu = clamp((u - a) / (b - a), 0.0, 1.0);
        // the glass: mostly clear, with two coloured patches that blend softly across the fan
        // (a window's colours smear together in the air, they don't make stripes)
        float g1 = smoothstep(0.5, 0.85, n1(u * 3.2 + 1.3));
        float g2 = smoothstep(0.55, 0.9, n1(u * 3.2 + 7.9)) * (1.0 - g1);
        vec3 pane = mix(mix(uPane[0], uPane[2], g1), uPane[5], g2);
        float rays = (0.5 + 0.5 * n1(u * 60.0 + float(k) * 13.0)) * (0.45 + 0.55 * n1(u * 17.0 + 5.0));
        c += m * rays * pane;
    }
    return c;
}

// ---- smoke density at p (y up, 0..1 over the height), looping in t
float smoke(vec2 p, float t) {
    // noise space: one unit ~ 0.6 screen heights; repeats every 4 units up (the smoke rises one
    // period per loop) and every 3 units in the evolution axis
    vec3 per = vec3(289.0, 4.0, 3.0);
    vec3 q = vec3(p.x * 1.7, p.y * 1.7 - 4.0 * t, 3.0 * t);
    vec2 w = vec2(fbm(q + vec3(0.0, 0.0, 0.0), per), fbm(q + vec3(5.2, 1.3, 1.7), per));
    vec3 r = q + vec3(1.6 * w, 0.0);
    float d = fbm(r + vec3(1.7, 9.2, 0.4), per);
    // wisps: the thin ridges of the warped noise; haze: its broad swells
    float wisp = pow(clamp(1.0 - abs(d) * 3.2, 0.0, 1.0), 3.0);
    float haze = clamp(w.x * 1.4 + 0.25, 0.0, 1.0);
    // heavier near the floor, thin wisps up high; a gentle column right of centre
    float floorish = mix(0.35, 1.0, smoothstep(1.05, 0.0, p.y));
    float column = 0.55 + 0.45 * exp(-pow((p.x - 1.05) / 0.55, 2.0));
    return (0.75 * wisp * (0.35 + 0.65 * haze) + 0.3 * haze * haze) * floorish * column;
}

void main() {
    vec2 frc = gl_FragCoord.xy;
    vec2 p = frc / uRes.y;                // x 0..aspect, y 0..1 (up)
    float asp = uRes.x / uRes.y;
    float t = uT;

    // the room: dark, a touch lighter low where the light lands
    vec3 amb = mix(uBgDark, uBg, 0.35 * smoothstep(1.2, 0.0, length((p - vec2(0.62, -0.1)) * vec2(0.8, 1.2))));
    vec3 col = amb * (uLight > 0.5 ? 1.0 : 0.55);

    // the window's light: rays fan out from above the top-right corner
    vec2 S = vec2(asp * 1.22, 2.5);
    vec2 d = p - S;
    float dist = length(d);
    float ang = atan(-d.x, -d.y);         // 0 = straight down, + towards the left
    float u = (ang - 0.36) / 0.24;        // the window spans these angles
    float soft = 0.004 + 0.02 * max(dist - 1.4, 0.0);
    vec3 beam = window(u, soft) + 0.35 * window((u - 1.22) / 0.26, soft / 0.26);
    // a faint wide glow around the shafts (light scattered off the window reveals)
    float halo = smoothstep(-0.45, 0.2, u) * (1.0 - smoothstep(1.4, 1.9, u));
    float reach = smoothstep(1.35, 1.75, dist) * exp(-0.8 * max(dist - 1.75, 0.0));

    float sm = smoke(p, t) * uSmoke;
    float air = 0.035 + 2.6 * sm;
    vec3 light = uLightCol * uPower;
    col += light * beam * reach * air * 0.75;
    col += light * halo * reach * (0.05 + 0.22 * sm) * 0.35;
    // smoke outside the beams, only faintly lit by the room
    col += uSmokeCol * sm * 0.045;

    // dust motes: three depths; glint only where the beams are
    for (int layer = 0; layer < 3; layer++) {
        float cell = 0.045 + 0.04 * float(layer);
        float rad = 0.0011 + 0.0012 * float(layer * layer);
        vec2 g = floor(p / cell);
        for (int oy = -1; oy <= 1; oy++) for (int ox = -1; ox <= 1; ox++) {
            vec2 c = g + vec2(ox, oy);
            float n = dot(c, vec2(17.31, 91.7)) + float(layer) * 311.0;
            if (h1(n + 3.1) > 0.4) continue;
            vec2 base = (c + vec2(h1(n), h1(n + 1.7))) * cell;
            float f1 = 1.0 + floor(h1(n + 2.2) * 2.0), f2 = 1.0 + floor(h1(n + 4.4) * 2.0);
            vec2 m = base + cell * 0.4 * vec2(sin(TAU * (f1 * t + h1(n + 5.0))), 0.6 * sin(TAU * (f2 * t + h1(n + 6.0))));
            float r = length(p - m);
            float blur = rad * (1.0 + 1.2 * float(layer));
            float spot = exp(-r * r / (blur * blur));
            if (spot < 0.002) continue;
            vec2 md = m - S;
            float mu = (atan(-md.x, -md.y) - 0.36) / 0.24;
            vec3 lit = (window(mu, 0.02) + 0.35 * window((mu - 1.22) / 0.26, 0.08)) * smoothstep(1.35, 1.75, length(md));
            float tw = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TAU * (floor(3.0 + h1(n + 7.0) * 5.0) * t + h1(n + 8.0))), 3.0);
            col += light * lit * spot * tw * (1.1 - 0.3 * float(layer)) * 0.8;
        }
    }

    // sparks: embers rising, wandering witch-lights, or blinking fireflies
    for (int i = 0; i < 96; i++) {
        if (i >= uSparkCount) break;
        float n = float(i) * 13.17 + 5.0;
        vec2 sp; float a; float sz;
        if (uSparkKind == 1) {
            float k = 1.0 + floor(h1(n) * 3.0);
            float ph = fract(h1(n + 1.0) + k * t);
            sp = vec2(asp * (0.25 + 0.85 * h1(n + 2.0)) + 0.06 * sin(TAU * (2.0 * k * t + h1(n + 3.0))) + ph * 0.25,
                      -0.1 + ph * 1.25);
            a = smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.45, 0.95, ph))
                * (0.6 + 0.4 * sin(TAU * (7.0 * t + h1(n + 4.0))));
            sz = 0.0012 + 0.0016 * h1(n + 5.0);
        } else if (uSparkKind == 2) {
            vec2 c0 = vec2(asp * (0.3 + 0.6 * h1(n)), 0.12 + 0.62 * h1(n + 1.0));
            sp = c0 + vec2(0.16 * sin(TAU * (t + h1(n + 2.0))), 0.07 * sin(TAU * (2.0 * t + h1(n + 3.0))));
            a = 0.35 + 0.35 * sin(TAU * (3.0 * t + h1(n + 4.0)));
            sz = 0.0022;
        } else {
            vec2 c0 = vec2(asp * (0.22 + 0.75 * h1(n)), 0.04 + 0.5 * h1(n + 1.0));
            sp = c0 + vec2(0.05 * sin(TAU * (2.0 * t + h1(n + 2.0))), 0.03 * sin(TAU * (3.0 * t + h1(n + 3.0))));
            float blink = fract(4.0 * t + h1(n + 4.0));
            a = smoothstep(0.0, 0.05, blink) * (1.0 - smoothstep(0.08, 0.2, blink));
            sz = 0.0018;
        }
        float r = length(p - sp);
        col += uSparkCol * a * (exp(-r * r / (sz * sz)) * 1.6 + exp(-r / (sz * 9.0)) * 0.12);
    }

    // a soft vignette, darkest behind the bar and the spine
    float vig = smoothstep(1.35, 0.35, length((p - vec2(asp * 0.55, 0.45)) * vec2(0.62, 1.0)));
    col *= mix(uLight > 0.5 ? 0.82 : 0.55, 1.0, vig);
    col *= 1.0 - (uLight > 0.5 ? 0.06 : 0.25) * smoothstep(0.93, 1.0, p.y);
    col *= 1.0 - (uLight > 0.5 ? 0.04 : 0.18) * smoothstep(0.045, 0.0, p.x / asp);

    // highlights roll off softly; then to sRGB with a little dither against banding
    col = col / (1.0 + 0.35 * max(max(col.r, col.g), col.b));
    col = pow(max(col, 0.0), vec3(1.0 / 2.2));
    col += (fract(sin(dot(frc, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
    frag = vec4(col, 1.0);
}
"""


def palette(tid):
    with open(f"{HERE}/themes/{tid}.toml", "rb") as f:
        return tomllib.load(f)


class Renderer:
    def __init__(self, tid):
        th = palette(tid)
        p = th["palette"]
        look = LOOKS[tid]
        light_theme = th.get("appearance") == "light"
        self.frames = SECONDS * FPS
        self.ctx = moderngl.create_standalone_context(backend="egl")
        self.prog = self.ctx.program(vertex_shader=VERT, fragment_shader=FRAG)
        vbo = self.ctx.buffer(np.array([-1, -1, 3, -1, -1, 3], dtype="f4").tobytes())
        self.vao = self.ctx.vertex_array(self.prog, [(vbo, "2f", "pos")])
        self.fbo = self.ctx.simple_framebuffer((W, H), components=3)
        self.fbo.use()

        light = rgb(look["light"])
        panes = []
        for key in look["panes"]:
            c = (1, 1, 1) if key == "light" else rgb(p.get(key, key))
            # glass tints the light: mix plain light with the pane's colour, brightened
            peak = max(c) or 1
            tint = tuple(v / peak for v in c)
            panes.append(tuple(lin(tuple((1 - look["glass"]) + look["glass"] * v for v in tint))))
        u = self.prog
        u["uRes"].value = (W, H)
        u["uLight"].value = 1.0 if light_theme else 0.0
        bg, bgd = rgb(p["bg"]), rgb(p["bgDark"])
        if light_theme:      # a dim room by daylight, not the page colour: the beams need contrast
            bg = tuple(v * 0.9 for v in bg)
            bgd = tuple(v * 0.74 for v in bgd)
        u["uBg"].value = lin(bg)
        u["uBgDark"].value = lin(bgd)
        u["uLightCol"].value = lin(light)
        u["uSmokeCol"].value = lin(rgb(p["parchmentDeep"] if not light_theme else p["parchment"]))
        kind, count, col = look["sparks"]
        u["uSparkCol"].value = lin(rgb(p[col]))
        u["uSparkKind"].value = kind
        u["uSparkCount"].value = count
        u["uPane"].write(np.array(panes, dtype="f4").tobytes())
        u["uPower"].value = look["power"] * (1.9 if light_theme else 1.0)
        u["uSmoke"].value = look["smoke"]

    def render(self, n):
        self.prog["uT"].value = (n % self.frames) / self.frames
        self.fbo.clear()
        self.vao.render(moderngl.TRIANGLES)
        return self.fbo.read(components=3)          # bottom-up rows; ffmpeg flips


def encoder():
    enc = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    if "hevc_nvenc" in enc:
        probe = subprocess.run(["ffmpeg", "-hide_banner", "-f", "lavfi", "-i", "color=s=256x256:d=0.1", "-c:v", "hevc_nvenc",
                                "-f", "null", "-"], capture_output=True)
        if probe.returncode == 0:
            return ["-c:v", "hevc_nvenc", "-preset", "p7", "-tune", "hq", "-rc", "vbr", "-cq", "24", "-b:v", "0",
                    "-profile:v", "main", "-tag:v", "hvc1"]
    return ["-c:v", "libx264", "-preset", "slow", "-crf", "20", "-profile:v", "high"]


def link(src, folder):
    os.makedirs(folder, exist_ok=True)
    dst = os.path.join(folder, os.path.basename(src))
    if os.path.lexists(dst):
        os.unlink(dst)
    try:
        os.link(src, dst)
    except OSError:
        os.symlink(src, dst)


def make(tid):
    r = Renderer(tid)
    out = f"{POOL}/grimoire-{tid}-light.mp4"
    tmp = out + ".part.mp4"
    ff = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                           "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-vf", "vflip"] + encoder()
                          + ["-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", tmp], stdin=subprocess.PIPE)
    for i in range(r.frames):
        ff.stdin.write(r.render(i))
        if i % (FPS * 2) == 0:
            print(f"\r{tid}: {i * 100 // r.frames}%", end="", file=sys.stderr, flush=True)
    ff.stdin.close()
    if ff.wait() != 0:
        sys.exit(f"ffmpeg failed for {tid}")
    os.replace(tmp, out)
    link(out, f"{LIBRARY}/grimoire/{tid}")
    print(f"\r{tid}: done  {out}", file=sys.stderr)
    return out


def still(tid, sec, path):
    r = Renderer(tid)
    data = r.render(int(float(sec) * FPS))
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                    "-s", f"{W}x{H}", "-i", "-", "-vf", "vflip", "-frames:v", "1", path], input=data, check=True)


def main(args):
    if args and args[0] == "--frame":
        still(args[1], args[2], args[3])
        return
    tids = args or sorted(f[:-5] for f in os.listdir(f"{HERE}/themes") if f.endswith(".toml"))
    for tid in tids:
        print(make(tid))


if __name__ == "__main__":
    main(sys.argv[1:])
