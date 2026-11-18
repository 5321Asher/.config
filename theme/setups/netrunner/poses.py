#!/usr/bin/env python3
"""Netrunner's ripperdoc poses (quickshell/netrunner/rig/Ripperdoc.qml): how the hologram stands for
each implant, compiled into rig/poses.json.

Each pose is written here the way you'd direct it (bend this, put that hand there) and compiled
against the skeleton in rig/body.json (made by body.py) into one local rotation (a quaternion) per
bone, plus a shift of the hips. The shell only blends between those: no solving at runtime.

A pose is a dict of:
    "bone": [x, y, z]       a local turn (degrees, Qt's order: y after x after z), in the parent's
                            axes: +x is the body's left (the screen's right as it faces you), +y up,
                            +z forward. So x > 0 tips a hanging limb backwards (or the head down),
                            y > 0 turns towards the body's left, z > 0 rolls the top towards its right.
    "!bone": [x, y, z]      the same, but a turn from the rest pose in the body's own axes, whatever
                            the bones above it do (feet flat on the floor, say)
    "@arm.L": [to, pole]    put the wrist at `to` (metres, model space), the elbow pointing to `pole`
    "@leg.L": [to, pole]    the ankle at `to`, the knee towards `pole`
    "@hand.L": [point, palm]  the hand's fingers pointing along `point`, its palm facing `palm`
    "@twist.L": deg         turn the forearm about its length
    "@curl.L": [fingers, thumb] or [thumb, index, middle, ring, little]   curl the fingers (deg)
    "@hips": [x, y, z]      move the whole body (metres)
    "@view": deg            film it from this side (the camera's turn about the body; + is its left)
    "@frame": [y, dist]     and frame it there (the height looked at, how far back), not on the implant
    "base": "pose"          start from another pose

    ~/.local/share/theme/venv/bin/python poses.py <rig dir> [--preview out.png [pose ...]]
    (needs numpy; the preview needs Pillow)
"""
import json
import math
import os
import sys

import numpy as np

# where the hands go: the body's landmarks (rest pose, from body.py) are
#   temple R [-0.07, 1.69, 0.06]  heart [0.06, 1.318, 0.093]  shoulder L [0.18, 1.45, -0.06]
#   hip L [0.12, 0.935, -0.06]  ankle L [0.237, 0.078, -0.073]   an arm is 0.25 + 0.25, a leg 0.455 + 0.41
POSES = {
    # the overview: weight on the left leg, the hips and shoulders tilted against each other
    "stand": {
        "@hips": [0.02, -0.006, 0], "root": [0, -6, 3],
        "spine05": [0, 0, -1], "spine04": [1, 2, -2], "spine03": [0, 2, -1], "spine02": [-3, 3, -1], "spine01": [0, 2, 1],
        "neck01": [0, 4, -1], "neck02": [0, 4, -1], "head": [4, 9, -3],
        "upperarm01.L": [-4, 0, -30], "lowerarm01.L": [-14, 0, 0],
        "upperarm01.R": [6, 0, 27], "lowerarm01.R": [-8, 0, 0],
        "upperleg01.L": [0, 0, -6], "lowerleg01.L": [0, 0, 1],
        "upperleg01.R": [-10, -12, 1], "lowerleg01.R": [14, 0, 0], "foot.R": [-6, 0, 0],
        "@curl.L": [30, 10], "@curl.R": [30, 10],
    },
    # frontal cortex: two fingers to the temple, jacking in
    "temple": {
        "base": "stand", "head": [8, -10, 10], "neck02": [2, -4, 4],
        "@arm.R": [[-0.15, 1.56, 0.07], [-1, -0.7, -0.2]], "@hand.R": [[0.35, 1, 0.05], [1, -0.1, 0.2]],
        "@curl.R": [40, 0, 5, 85, 90],
    },
    # ocular system: a hand shading the eyes, looking far out
    "visor": {
        "base": "stand", "head": [-8, -16, 2], "spine01": [-3, -4, 0],
        "@arm.R": [[-0.13, 1.69, 0.16], [-1, -0.4, 0]], "@hand.R": [[1, 0.15, 0.25], [0, -1, -0.3]],
        "@curl.R": [10, 5, 5, 8, 12],
    },
    # operating system: head bowed, a hand at the port in the back of the neck
    "port": {
        "base": "stand", "head": [22, 8, -6], "neck01": [8, 0, -3], "neck02": [6, 0, 0],
        "@arm.R": [[-0.08, 1.55, -0.13], [-0.3, 1, 0.7]], "@hand.R": [[1, 0.35, 0], [0, 0, 1]],
        "@curl.R": [20, 25],
    },
    # circulatory system: a hand over the heart, head down
    "heart": {
        "base": "stand", "head": [16, 8, 2], "neck02": [4, 0, 0],
        "@arm.R": [[-0.01, 1.26, 0.135], [-1, -1, 0.1]], "@hand.R": [[0.8, 0.55, 0], [0, 0, -1]],
        "@curl.R": [8, 5],
    },
    # immune system: hands on the hips, chin up
    "hips": {
        "base": "stand", "root": [0, -4, 0], "@hips": [0, 0, 0],
        "upperleg01.L": [0, 0, 1], "lowerleg01.L": [0, 0, 0], "upperleg01.R": [0, 0, -1], "lowerleg01.R": [0, 0, 0], "foot.R": [0, 0, 0],
        "spine02": [-6, 0, 0], "head": [-8, 6, 0],
        "@arm.L": [[0.17, 1.0, 0.0], [1, 0, -0.6]], "@hand.L": [[-0.15, -0.6, 1], [-1, 0, 0]],
        "@arm.R": [[-0.17, 1.0, 0.0], [-1, 0, -0.6]], "@hand.R": [[0.15, -0.6, 1], [1, 0, 0]],
        "@curl.L": [25, 10], "@curl.R": [25, 10],
    },
    # nervous system: arms open, palms out, taking every signal in
    "open": {
        "base": "stand", "root": [0, 0, 0], "@hips": [0, 0, 0],
        "upperarm01.L": [-15, 0, 35], "upperarm01.R": [-15, 0, -35], "lowerarm01.L": [-10, 0, 0], "lowerarm01.R": [-10, 0, 0],
        "upperleg01.L": [0, 0, -2], "lowerleg01.L": [0, 0, 0], "upperleg01.R": [0, 0, 2], "lowerleg01.R": [0, 0, 0], "foot.R": [0, 0, 0],
        "head": [-14, 0, 0], "spine02": [-8, 0, 0], "spine01": [-4, 0, 0],
        "@hand.L": [[1, 0.25, 0.1], [0, 0.2, 1]], "@hand.R": [[-1, 0.25, 0.1], [0, 0.2, 1]],
        "@curl.L": [-8, -10], "@curl.R": [-8, -10],
    },
    # integumentary system: a hand held out to the rain, looking up at it
    "rain": {
        "base": "stand", "head": [-26, 26, 0], "neck02": [-6, 6, 0], "spine01": [-4, 4, 0], "@view": 20, "@frame": [1.1, 2.8],
        "@arm.L": [[0.32, 1.55, 0.36], [1, -1, 0]], "@hand.L": [[0.25, 0.3, 1], [0, 1, 0]],
        "@curl.L": [12, 0],
    },
    # skeleton: a fighting stance, fists up
    "guard": {
        "base": "stand", "root": [0, -25, 0], "@hips": [0, -0.075, 0], "@view": -30, "@frame": [1.12, 2.4],
        "spine04": [4, 4, 0], "spine02": [4, 4, 0], "head": [12, 14, 0],
        "@leg.L": [[0.08, 0.078, 0.2], [0.2, 0, 1]], "!foot.L": [0, -20, 0],
        "@leg.R": [[-0.24, 0.078, -0.24], [-0.2, 0, 1]], "!foot.R": [0, -55, 0],
        "@arm.L": [[0.0, 1.5, 0.3], [0.5, -1, -0.1]], "@hand.L": [[-0.1, 1, 0.5], [-1, 0, 0]],
        "@arm.R": [[-0.18, 1.47, 0.12], [-0.5, -1, -0.1]], "@hand.R": [[0.1, 1, 0.4], [1, 0, 0]],
        "@curl.L": [100, 60], "@curl.R": [100, 60],
    },
    # hands: one held up in front, palm up, looked over
    "palm": {
        "base": "stand", "head": [22, 22, 0], "neck02": [6, 4, 0],
        "@arm.L": [[0.19, 1.17, 0.31], [0.3, -1, -0.4]], "@hand.L": [[-0.3, 0.1, 1], [0, 1, 0]],
        "@curl.L": [12, 0],
    },
    # arms: a flexed arm, fist closed
    "flex": {
        "base": "stand", "head": [4, 34, 4], "spine02": [-6, 0, 0], "@view": 28, "@frame": [1.45, 1.9],
        "@arm.L": [[0.44, 1.72, 0.0], [1, -0.2, -0.3]], "@hand.L": [[0, 1, 0], [-1, 0, 0]],
        "@curl.L": [100, 60],
    },
    # legs: mid-stride, the left knee driving up
    "stride": {
        "base": "stand", "root": [0, 0, 0], "@hips": [0, -0.05, 0.03], "@view": 62, "@frame": [0.8, 2.7],
        "spine04": [10, 0, 0], "spine02": [4, 0, 0], "head": [-12, 0, 0],
        "@leg.L": [[0.12, 0.45, 0.3], [0, 0.3, 1]], "!foot.L": [30, 0, 0],
        "@leg.R": [[-0.1, 0.078, -0.16], [0, 0, 1]], "!foot.R": [0, 0, 0],
        "@arm.R": [[-0.1, 1.3, 0.32], [-0.3, -1, -0.6]], "@hand.R": [[0, 1, 0.3], [1, 0, 0]],
        "@arm.L": [[0.22, 1.02, -0.18], [0.2, -0.2, -1]], "@hand.L": [[0, -0.3, 1], [-1, 0, 0]],
        "@curl.L": [80, 40], "@curl.R": [80, 40],
    },
}
# which pose each implant strikes ("" is the whole body)
PAGES = {"": "stand", "claude": "temple", "optics": "visor", "helm": "port", "telemetry": "heart",
         "log": "hips", "comms": "open", "almanac": "rain", "hangar": "guard", "lamps": "palm",
         "radio": "flex", "chronometer": "stride"}


# ---------------------------------------------------------------- quaternions (w, x, y, z)
def qmul(a, b):
    w1, x1, y1, z1 = a
    w2, x2, y2, z2 = b
    return np.array([w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2, w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
                     w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2])
def qinv(q): return np.array([q[0], -q[1], -q[2], -q[3]])
def qaxis(axis, deg):
    h = math.radians(deg) / 2
    return np.array([math.cos(h), *(np.asarray(axis, dtype=float) * math.sin(h))])
def euler(e):
    return qmul(qmul(qaxis([0, 1, 0], e[1]), qaxis([1, 0, 0], e[0])), qaxis([0, 0, 1], e[2]))
def qrot(q, v):
    u = q[1:]
    return v + 2 * np.cross(u, np.cross(u, v) + q[0] * v)
def qmat(q):
    w, x, y, z = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
                     [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
                     [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]])
def qfrom(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1) * 2
        q = [0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [(m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s]
    else:
        s = math.sqrt(1 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s]
    q = np.array(q)
    return q / np.linalg.norm(q)
def unit(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)
def frame(a, b):
    a = unit(a)
    b = unit(b - a * np.dot(a, b))
    return np.stack([a, b, np.cross(a, b)], axis=1)
def turn(a1, b1, a2, b2):
    """The rotation taking direction a1 to a2, and b1 (as near as it can) to b2."""
    return qfrom(frame(a2, b2) @ frame(a1, b1).T)
def between(a, b):
    a, b = unit(a), unit(b)
    c = np.cross(a, b)
    if np.linalg.norm(c) < 1e-8:
        return np.array([1.0, 0, 0, 0])
    return qaxis(unit(c), math.degrees(math.atan2(np.linalg.norm(c), np.dot(a, b))))


class Rig:
    def __init__(self, rig_dir):
        self.body = json.load(open(os.path.join(rig_dir, "body.json")))
        self.bones = self.body["bones"]
        self.n = len(self.bones)
        self.idx = {b["name"]: i for i, b in enumerate(self.bones)}
        self.H = np.array([b["head"] for b in self.bones])
        self.par = [b["parent"] for b in self.bones]
        H, idx = self.H, self.idx
        self.curl = {}
        self.hand = {}
        for sd, sign in ((".L", 1), (".R", -1)):
            lat = unit(H[idx["finger5-1" + sd]] - H[idx["finger2-1" + sd]])
            lng = unit(H[idx["finger3-1" + sd]] - H[idx["wrist" + sd]])
            palm = np.cross(lng, lat)
            if palm[0] * sign > 0:
                palm = -palm
            self.hand[sd] = (lng, palm)
            for f in range(2, 6):
                for k in (1, 2, 3):
                    self.curl[idx[f"finger{f}-{k}{sd}"]] = (sd, f, lat * sign, (1.0, 1.1, 0.8)[k - 1])
            for k in (1, 2, 3):
                self.curl[idx[f"finger1-{k}{sd}"]] = (sd, 1, lng * sign, (0.6, 0.6, 0.8)[k - 1])

    def resolve(self, name):
        pose = POSES[name]
        out = dict(self.resolve(pose["base"])) if "base" in pose else {}
        out.update({k: v for k, v in pose.items() if k != "base"})
        return out

    def solve(self, name):
        """The pose's local rotation of every bone, and the hips' shift."""
        pose = self.resolve(name)
        H, idx, par = self.H, self.idx, self.par
        G = [None] * self.n
        P = np.zeros((self.n, 3))
        L = [np.array([1.0, 0, 0, 0])] * self.n
        hips = np.array(pose.get("@hips", [0, 0, 0]), dtype=float)
        forced = {}                                  # local rotations the limbs' IK settled
        for i, b in enumerate(self.bones):
            nm = b["name"]
            p = par[i]
            Gp = G[p] if p >= 0 else np.array([1.0, 0, 0, 0])
            P[i] = P[p] + qrot(G[p], H[i] - H[p]) if p >= 0 else H[i] + hips
            q = euler(pose[nm]) if nm in pose else np.array([1.0, 0, 0, 0])
            if "!" + nm in pose:
                q = qmul(qinv(Gp), euler(pose["!" + nm]))
            if i in forced:
                q = forced[i]
            sd = nm[-2:]
            for kind, upper, mid, end in (("@arm", "upperarm01", "lowerarm01", "wrist"), ("@leg", "upperleg01", "lowerleg01", "foot")):
                if nm == upper + sd and kind + sd in pose:
                    to, pole = pose[kind + sd]
                    q, low = self.ik(P[i], Gp, idx[upper + sd], idx[mid + sd], idx[end + sd], np.array(to, dtype=float), np.array(pole, dtype=float), kind == "@leg")
                    forced[idx[mid + sd]] = low
            if nm == "lowerarm02" + sd and "@twist" + sd in pose:
                q = qmul(q, qaxis(unit(H[idx["wrist" + sd]] - H[idx["lowerarm01" + sd]]), pose["@twist" + sd]))
            if nm == "wrist" + sd and "@hand" + sd in pose:
                lng, palm = self.hand[sd]
                point, face = pose["@hand" + sd]
                q = qmul(qinv(Gp), turn(lng, palm, point, face))
            if i in self.curl:
                cs, f, axis, k = self.curl[i]
                c = pose.get("@curl" + cs, [0, 0])
                amt = (c[1] if f == 1 else c[0]) if len(c) == 2 else c[f - 1]
                if amt:
                    q = qmul(q, qaxis(axis, amt * k))
            L[i] = q / np.linalg.norm(q)
            G[i] = qmul(Gp, L[i])
        return hips, L, G, P

    def ik(self, S, Gp, upper, mid, end, T, pole, leg):
        """Two bones from S reaching T, bending towards `pole`: the upper and lower local rotations."""
        H = self.H
        a, b = np.linalg.norm(H[mid] - H[upper]), np.linalg.norm(H[end] - H[mid])
        u0, f0 = unit(H[mid] - H[upper]), unit(H[end] - H[mid])
        n0 = unit([1, 0, 0] - u0 * u0[0]) if leg else unit(np.cross(u0, f0))
        d = np.clip(np.linalg.norm(T - S), abs(a - b) + 1e-4, a + b - 1e-4)
        t = unit(T - S)
        T = S + t * d
        pp = unit(pole - t * np.dot(pole, t))
        ca = (a * a + d * d - b * b) / (2 * a * d)
        E = S + a * (ca * t + math.sqrt(max(0, 1 - ca * ca)) * pp)
        dE, dF = unit(E - S), unit(T - E)
        n1 = np.cross(dE, dF)
        n1 = unit(n1) if np.linalg.norm(n1) > 1e-6 else unit(np.cross(dE, pp))
        Gu = turn(u0, n0, dE, n1)
        Gf = qmul(between(qrot(Gu, f0), dF), Gu)
        return qmul(qinv(Gp), Gu), qmul(qinv(Gu), Gf)


def preview(rig, out, names):
    from PIL import Image, ImageDraw
    B = rig.body
    H = rig.H
    def skin(pos, J, W, G, P):
        res = np.zeros_like(pos)
        M = np.array([qmat(g) for g in G])
        for k in range(4):
            j = J[:, k]
            res += W[:, k][:, None] * (np.einsum("nij,nj->ni", M[j], pos - H[j]) + P[j])
        return res
    bp, bj, bw = np.array(B["p"]).reshape(-1, 3), np.array(B["j"]).reshape(-1, 4), np.array(B["w"]).reshape(-1, 4)
    V = B["vessels"]
    vp, vj, vw = np.array(V["p"]).reshape(-1, 3), np.array(V["j"]).reshape(-1, 4), np.array(V["w"]).reshape(-1, 4)
    left = vp[:, 0] > 0.02
    S = 420
    zc, zk = float(os.environ.get("ZY", "0.9")), float(os.environ.get("ZK", "1"))
    img = Image.new("RGB", (S * 3, (S + 20) * len(names)), (8, 4, 6))
    dr = ImageDraw.Draw(img)
    for row, name in enumerate(names):
        _, _, G, P = rig.solve(name)
        body, ves = skin(bp, bj, bw, G, P), skin(vp, vj, vw, G, P)
        for col, yaw in enumerate((0, 40, 90)):
            c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
            k = S / 2.1 * zk
            arr = np.zeros((S, S, 3))
            for pts, colr, a in ((body, (0.6, 0.15, 0.15), 0.12), (ves[left], (0.2, 0.9, 1.0), 0.35), (ves[~left], (1.0, 0.85, 0.2), 0.35)):
                x = pts[:, 0] * c + pts[:, 2] * s
                px = (x * k + S / 2).astype(int)
                py = (S / 2 - (pts[:, 1] - zc) * k).astype(int)
                ok = (px >= 0) & (px < S) & (py >= 0) & (py < S)
                np.add.at(arr, (py[ok], px[ok]), np.array(colr) * a)
            fy = int(S / 2 + zc * k)
            if 0 <= fy < S:
                arr[fy, :] += 0.3
            img.paste(Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)), (col * S, row * (S + 20) + 20))
        dr.text((6, row * (S + 20) + 4), name, fill=(255, 220, 90))
    img.save(out)


def main():
    rig_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    rig = Rig(rig_dir)
    if "--preview" in sys.argv:
        k = sys.argv.index("--preview")
        preview(rig, sys.argv[k + 1], sys.argv[k + 2:] or list(POSES))
        return
    poses = {}
    for name in POSES:
        hips, L, _, _ = rig.solve(name)
        poses[name] = {"hips": [round(float(x), 4) for x in hips],
                       "q": {str(i): [round(float(x), 5) for x in q] for i, q in enumerate(L) if abs(q[0]) < 0.99999}}
        for key in ("view", "frame"):
            if "@" + key in rig.resolve(name):
                poses[name][key] = rig.resolve(name)["@" + key]
    path = os.path.join(rig_dir, "poses.json")
    with open(path, "w") as f:
        json.dump({"poses": poses, "pages": PAGES}, f, separators=(",", ":"))
    print(f"{len(poses)} poses -> {path} ({os.path.getsize(path) // 1024} KB)")


if __name__ == "__main__":
    main()
