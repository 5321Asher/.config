#!/usr/bin/env python3
"""Netrunner's ripperdoc body (quickshell/netrunner/rig/Ripperdoc.qml): a real human, posable, with a
circulatory system.

The mesh is MakeHuman's base mesh, its default skeleton and that skeleton's skin weights (all three
released as CC0: see the headers of base.obj, default.mhskel and default_weights.mhw). This keeps
only the "body" group of the mesh, scales everything to 1.8 m with the feet at y = 0, splits the quads
into triangles, gives smooth normals, keeps each vertex's four strongest bones, and builds the
vessels: tubes following the skeleton from the heart (the aorta down the spine, arteries down each
limb to every finger and toe, the carotids up the neck and over the skull), each point weighted to
the bone it runs along (blending at the joints) and carrying its distance from the heart, so the
shader can send pulses outwards. rig/body.json holds the body (p n i j w), the vessels (p n u i j w)
and the bones (name, parent, head, tail) for Qt Quick 3D (ProceduralMesh + Skin). It prints some
landmarks to place the implants' anchors in rig/RigState.qml.

    ~/.local/share/theme/venv/bin/python body.py <rig dir> [dir with base.obj, default.mhskel, default_weights.mhw]
    (needs numpy; downloads what's missing to ~/.cache/makehuman), then poses.py <rig dir>
"""
import json
import os
import sys
import urllib.request

import numpy as np

RAW = "https://raw.githubusercontent.com/makehumancommunity/makehuman/master/makehuman/data/"
FILES = {"base.obj": "3dobjs/base.obj", "default.mhskel": "rigs/default.mhskel", "default_weights.mhw": "rigs/default_weights.mhw"}
HEIGHT = 1.8


def load(path):
    verts, faces, group = [], [], None
    for line in open(path):
        if line.startswith("v "):
            verts.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("g "):
            group = line.split()[1]
        elif line.startswith("f ") and group == "body":
            faces.append([int(t.split("/")[0]) - 1 for t in line.split()[1:]])
    return np.array(verts), faces


def fetch(src):
    os.makedirs(src, exist_ok=True)
    for name, rel in FILES.items():
        if not os.path.exists(os.path.join(src, name)):
            urllib.request.urlretrieve(RAW + rel, os.path.join(src, name))


def unit(a):
    return np.asarray(a, dtype=float) / np.linalg.norm(a)


def tube(points, radii, uvs, bones, ring=6):
    """A tube along `points` (radius, uv and bones of each point given), as vertices (position,
    normal, uv, joints and weights) and triangles."""
    P = np.array(points)
    n = len(P)
    T = np.gradient(P, axis=0)
    T /= np.maximum(np.linalg.norm(T, axis=1, keepdims=True), 1e-9)
    up = np.array([0.0, 0.0, 1.0]) if abs(T[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    N = np.cross(T[0], up); N /= np.linalg.norm(N)
    verts, faces = [], []
    for i in range(n):
        if i:                       # parallel transport the frame
            N = N - np.dot(N, T[i]) * T[i]
            N /= max(np.linalg.norm(N), 1e-9)
        Bn = np.cross(T[i], N)
        for k in range(ring):
            a = 2 * np.pi * k / ring
            d = np.cos(a) * N + np.sin(a) * Bn
            verts.append((P[i] + d * radii[i], d, tuple(uvs[i]), bones[i]))
    for i in range(n - 1):
        for k in range(ring):
            a, b = i * ring + k, i * ring + (k + 1) % ring
            c, d = a + ring, b + ring
            faces += [[a, c, b], [b, c, d]]
    return verts, faces


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    src = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.cache/makehuman")
    fetch(src)
    vall, faces = load(os.path.join(src, "base.obj"))
    used = np.unique([i for f in faces for i in f])
    assert used[0] == 0 and used[-1] == len(used) - 1, "body vertices aren't the first ones"
    v = vall[:len(used)].copy()
    tris = []
    for f in faces:
        for k in range(1, len(f) - 1):
            tris.append([f[0], f[k], f[k + 1]])
    tris = np.array(tris)

    # 1.8 m tall, feet on the floor, the torso over the origin (the same for the skeleton's joints)
    s = HEIGHT / (v[:, 1].max() - v[:, 1].min())
    off = np.array([0, v[:, 1].min(), 0])
    place = lambda p: (p - off) * s
    v = place(v)
    vall = place(vall)
    torso = v[(v[:, 1] > 1.0) & (v[:, 1] < 1.4) & (np.abs(v[:, 0]) < 0.15)]
    shift = np.array([0, 0, torso[:, 2].mean()])
    v -= shift
    vall -= shift

    fn = np.cross(v[tris[:, 1]] - v[tris[:, 0]], v[tris[:, 2]] - v[tris[:, 0]])
    nrm = np.zeros_like(v)
    for k in range(3):
        np.add.at(nrm, tris[:, k], fn)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)

    # the skeleton: parents before children
    sk = json.load(open(os.path.join(src, "default.mhskel")))
    bones = sk["bones"]
    order, seen = [], set()
    def visit(b):
        if b in seen: return
        if bones[b]["parent"]: visit(bones[b]["parent"])
        seen.add(b); order.append(b)
    for b in bones: visit(b)
    index = {b: i for i, b in enumerate(order)}
    names = order
    joint = lambda key: vall[sk["joints"][key]].mean(axis=0)
    head = {b: joint(bones[b]["head"]) for b in order}
    tail = {b: joint(bones[b]["tail"]) for b in order}

    # skin weights: each vertex's four strongest bones, normalised
    wt = json.load(open(os.path.join(src, "default_weights.mhw")))["weights"]
    per = [[] for _ in range(len(v))]
    for b, pairs in wt.items():
        for vi, w in pairs:
            if vi < len(v): per[vi].append((w, index[b]))
    J = np.zeros((len(v), 4), dtype=np.int64)
    W = np.zeros((len(v), 4))
    for vi, lst in enumerate(per):
        lst = sorted(lst, reverse=True)[:4] or [(1.0, index["root"])]
        tot = sum(w for w, _ in lst)
        for k, (w, b) in enumerate(lst):
            J[vi, k], W[vi, k] = b, w / tot

    # ---- the vessels: a tree of tubes from the heart, each point riding the bone it runs along
    dom = J[:, 0]                                  # each body vertex's strongest bone
    rng = np.random.default_rng(7)
    heart = head["spine02"] * 0.3 + head["spine01"] * 0.7 + np.array([0.03, -0.04, 0.085])
    vessels_v, vessels_f = [], []
    def vessel(pts, bon, r0, r1, d0=0.0, spacing=0.045, wander=1.0):
        """One tube through `pts` (bone indexes `bon`), radius r0 -> r1, starting `d0` metres from the
        heart; returns its points, their distances and bones. The path is evened out (`spacing`), rounded
        (two rounds of corner cutting) and wanders a little either side, as vessels do."""
        pts = np.array(pts, dtype=float)
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        at = np.concatenate([[0], np.cumsum(seg)])
        n = max(2, int(round(at[-1] / spacing)) + 1)
        u = np.linspace(0, at[-1], n)
        pts = np.stack([np.interp(u, at, pts[:, c]) for c in range(3)], axis=1)
        bon = [bon[min(len(bon) - 1, int(np.searchsorted(at, x, side="right")) - 1 + (1 if x - at[max(0, np.searchsorted(at, x, side="right") - 1)] > 0.5 * spacing else 0))] for x in u]
        for _ in range(2):
            if len(pts) < 3: break
            a, b = pts[:-1], pts[1:]
            mid = np.empty((2 * len(a), 3))
            mid[0::2], mid[1::2] = a * 0.75 + b * 0.25, a * 0.25 + b * 0.75
            pts = np.concatenate([pts[:1], mid, pts[-1:]])
            bon = [bon[0]] + [x for k in range(len(bon) - 1) for x in (bon[k], bon[k + 1])] + [bon[-1]]
        if wander and len(pts) > 3:
            at = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
            T = np.gradient(pts, axis=0)
            T /= np.maximum(np.linalg.norm(T, axis=1, keepdims=True), 1e-9)
            ref = np.where(np.abs(T[:, 2:3]) < 0.9, [[0, 0, 1.0]], [[1.0, 0, 0]])
            N = np.cross(T, ref); N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
            Bn = np.cross(T, N)
            env = np.clip(np.sin(np.pi * at / max(at[-1], 1e-6)), 0, 1) ** 0.5
            amp = min(0.0035, 0.5 * r0) * wander
            ph, ph2 = rng.uniform(0, 6.3, 2)
            pts = pts + (N * np.sin(at * 55 + ph)[:, None] + Bn * 0.7 * np.cos(at * 31 + ph2)[:, None]) * (amp * env)[:, None]
        d = d0 + np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
        radii = r1 + (r0 - r1) * (1 - (d - d0) / max(d[-1] - d0, 1e-6)) ** 1.3
        jw = []
        for k, bb in enumerate(bon):             # blend into the next bone where they meet
            nb = bon[k + 1] if k + 1 < len(bon) else bb
            jw.append(([bb, nb, 0, 0], [0.6, 0.4, 0, 0]) if nb != bb else ([bb, 0, 0, 0], [1, 0, 0, 0]))
        base = len(vessels_v)
        verts, fs = tube(pts, radii, np.stack([d, radii], axis=1), jw, ring=6 if r0 > 0.004 else 4)
        vessels_v.extend(verts)
        vessels_f.extend([[x + base, y + base, z + base] for x, y, z in fs])
        return pts, d, bon
    def along(chain, start=None, start_bone=None, rev=False, fwd=0.0, step=0.02):
        """Points down the bones of `chain` (tail to head with `rev`), after `start`."""
        pts, bon = ([start], [index[start_bone]]) if start is not None else ([], [])
        for name in chain:
            h, t = head[name] + [0, 0, fwd], tail[name] + [0, 0, fwd]
            if rev: h, t = t, h
            n = max(2, int(np.linalg.norm(t - h) / step) + 1)
            for k in range(n):
                q = h + (t - h) * k / (n - 1)
                if pts and np.linalg.norm(pts[-1] - q) < 1e-4: continue
                pts.append(q); bon.append(index[name])
        return pts, bon
    def curve(a, ctrl, c, n=6):
        t = np.linspace(0, 1, n)[:, None]
        return list((1 - t) ** 2 * a + 2 * (1 - t) * t * ctrl + t ** 2 * c)
    def skin(P, direction, axis, bone, near=0.025):
        """Where the skin is from P (on the bone's line) in `direction`, across the bone's `axis`."""
        rel = v - P
        sel = (np.abs(rel @ axis) < near) & (np.linalg.norm(rel, axis=1) < 0.2)
        own = sel & (dom == bone)
        if own.sum() < 6: return None
        r = rel[own]
        score = (r / np.linalg.norm(r, axis=1, keepdims=True)) @ direction
        return v[own][np.argmax(score)]
    def twigs(pts, d, bon, every=0.07, reach=0.8, r=0.0021, skip=0.04):
        """Small branches off a vessel, out towards the skin, forking once."""
        ang = rng.uniform(0, 2 * np.pi)
        nxt = d[0] + skip
        for k in range(1, len(pts) - 1):
            if d[k] < nxt or not names[bon[k]].startswith(("upperarm", "lowerarm", "upperleg", "lowerleg")): continue
            nxt = d[k] + every * rng.uniform(0.8, 1.25)
            axis = pts[k + 1] - pts[k - 1]; axis /= np.linalg.norm(axis)
            ref = np.array([0, 0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0, 0])
            u = np.cross(axis, ref); u /= np.linalg.norm(u); w2 = np.cross(axis, u)
            ang += 2.39996
            for fork, da in ((0, 0.0), (1, 0.55)):
                dirn = np.cos(ang + da) * u + np.sin(ang + da) * w2
                S = skin(pts[k], dirn, axis, bon[k])
                if S is None: continue
                out = (S - pts[k]) * reach
                out *= min(1.0, 0.075 / max(np.linalg.norm(out), 1e-6))
                S = pts[k] + out / reach
                end = pts[k] + out + axis * 0.035
                if fork:
                    s0 = pts[k] + (S - pts[k]) * 0.35 + axis * 0.012
                    vessel(curve(s0, s0 + axis * 0.012, end, 5), [bon[k]] * 5, r * 0.7, r * 0.35, d[k] + 0.02, spacing=0.03, wander=0.5)
                else:
                    vessel(curve(pts[k], pts[k] + axis * 0.02 + (S - pts[k]) * 0.2, end, 6), [bon[k]] * 6, r, r * 0.4, d[k], spacing=0.03, wander=0.5)

    # the heart, up through the aortic arch and down in front of the spine to the pelvis
    arch = np.array([0.0, heart[1] + 0.085, -0.005])
    behind = np.array([-0.005, heart[1] + 0.02, -0.035])
    pts = curve(heart, heart + [0, 0.07, -0.01], arch, 6) + curve(arch, arch + [-0.004, 0.02, -0.035], behind, 5)[1:]
    arc_pts, arc_d, _ = vessel(pts, [index["spine02"]] * len(pts), 0.011, 0.0105, spacing=0.02, wander=0)
    top = int(np.argmax(arc_pts[:, 1]))                  # the top of the arch: the arms and the neck branch off it
    top_d = arc_d[top]
    p2, b2 = along(["spine02", "spine03", "spine04", "spine05"], behind, "spine02", rev=True, fwd=0.04)
    aorta, d_aorta, b2 = vessel(p2, b2, 0.0105, 0.0075, arc_d[-1], wander=0.4)
    end, d_end = aorta[-1], d_aorta[-1]
    # round the ribs (sloping down to the front, as they do) and a few into the belly, off the aorta
    level = lambda y: int(np.argmin(np.abs(aorta[:, 1] - y)))
    for y0, rib in ((1.3, True), (1.215, True), (1.13, True), (1.04, False)):
        for side in (1, -1):
            k = level(y0 + (0.018 if side < 0 else 0))     # not quite level across: bodies aren't
            y = aorta[k][1]
            arc = [aorta[k]]
            ths = np.linspace(0.3 * np.pi, (0.86 if rib else 0.66) * np.pi, 14)
            for n, th in enumerate(ths):
                yy = y - (0.07 if rib else 0.03) * (n / (len(ths) - 1)) ** 1.4
                slab = v[(np.abs(v[:, 1] - yy) < 0.012) & (np.abs(v[:, 0]) < 0.24)]
                if len(slab) < 20: break
                c = np.array([0, yy, slab[:, 2].mean()])
                dirn = np.array([side * np.sin(th), 0, -np.cos(th)])
                rel = slab - c
                ok = (rel[:, 0] * side > -0.01) & ((rel / np.maximum(np.linalg.norm(rel, axis=1, keepdims=True), 1e-6)) @ dirn > 0.96)
                if not ok.any(): continue
                rad = np.linalg.norm(rel[ok], axis=1).max()
                arc.append(c + dirn * rad * (0.8 + 0.06 * rng.uniform()))
            if len(arc) > 3:
                vessel(arc, [b2[k]] * len(arc), 0.0023 if rib else 0.002, 0.0009, d_aorta[k], spacing=0.05)
    for side in (".L", ".R"):
        sx = 1 if side == ".L" else -1
        # down a leg to the foot, branching on the way, and on to every toe
        p, bb = along(["upperleg01" + side, "upperleg02" + side, "lowerleg01" + side, "lowerleg02" + side, "foot" + side],
                      end, "spine05", fwd=0.03)
        leg, dl, bb = vessel(p, bb, 0.0068, 0.003, d_end)
        twigs(leg, dl, bb, every=0.055)
        for t in range(1, 6):
            chain = [f"toe{t}-{k}{side}" for k in (1, 2, 3) if f"toe{t}-{k}{side}" in bones]
            p, bb = along(chain, leg[-1], "foot" + side, step=0.01)
            vessel(p, bb, 0.002, 0.001, dl[-1], spacing=0.025, wander=0.3)
        # out from the arch along an arm, branching, and on to every finger
        p, bb = along(["clavicle" + side, "shoulder01" + side, "upperarm01" + side, "upperarm02" + side,
                       "lowerarm01" + side, "lowerarm02" + side, "wrist" + side], arc_pts[top], "spine02")
        arm, da, bb = vessel(p, bb, 0.0052, 0.0026, top_d)
        twigs(arm[3:], da[3:], bb[3:], every=0.05)
        p, bb = along([f"finger1-{k}{side}" for k in (1, 2, 3)], arm[-1], "wrist" + side, step=0.008)
        vessel(p, bb, 0.0018, 0.0009, da[-1], spacing=0.025, wander=0.3)
        for m in range(1, 5):
            p, bb = along([f"metacarpal{m}{side}"] + [f"finger{m + 1}-{k}{side}" for k in (1, 2, 3)], arm[-1], "wrist" + side, step=0.008)
            vessel(p, bb, 0.0018, 0.0009, da[-1], spacing=0.025, wander=0.3)
        # a carotid up each side of the neck, then over the face and the skull
        p, bb = along(["neck01", "neck02", "neck03"], arc_pts[top], "spine02", fwd=0.03)
        p = [q + [sx * 0.034 * min(1, i / 2), 0, 0] for i, q in enumerate(p)]
        neck, dn, _ = vessel(p, bb, 0.0045, 0.0035, top_d)
        # past the angle of the jaw, then over the face and the skull just under the skin
        # (on an ellipsoid fitted to the skull, so the eye sockets and the ears don't snag them)
        hc = head["head"] * 0.55 + tail["head"] * 0.45 + [0, 0, 0.01]
        hv = v[(np.linalg.norm(v - hc, axis=1) < 0.17) & (v[:, 1] > neck[-1][1] + 0.01)] - hc
        axes = np.array([np.percentile(np.abs(hv[:, 0]), 97), np.percentile(np.abs(hv[:, 1]), 97), np.percentile(np.abs(hv[:, 2]), 95)])
        def onskin(direction, frac=0.86):
            return hc + direction / np.linalg.norm(direction / axes) * frac
        jaw = unit(np.array([sx * 0.7, -1.0, -0.05]))
        for dx, dy, dz, r in ((0.45, 0.55, 0.7, 0.0019), (0.9, 0.45, 0.25, 0.0022), (0.7, 0.75, -0.3, 0.0021),
                              (0.25, 0.97, 0.3, 0.0019), (0.75, -0.15, 0.55, 0.0017), (0.2, 0.75, -0.7, 0.0018),
                              (0.85, -0.2, -0.3, 0.0017), (0.15, 0.8, 0.6, 0.0016)):
            tip = unit(np.array([sx * dx, dy, dz]))
            path = [neck[-1]] + [onskin(unit(jaw * (1 - t) + tip * t)) for t in np.linspace(0, 1, 9)]
            vessel(path, [index["neck03"]] + [index["head"]] * 9, r, 0.0008, dn[-1], spacing=0.035, wander=0.6)

    VP = np.array([p for p, _, _, _ in vessels_v]); VN = np.array([n for _, n, _, _ in vessels_v])
    VU = np.array([u for _, _, u, _ in vessels_v]); VJ = np.array([j for _, _, _, (j, w) in vessels_v]); VW = np.array([w for _, _, _, (j, w) in vessels_v])

    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "body.json")
    r4 = lambda a, n=4: [round(float(x), n) for x in np.asarray(a).ravel()]
    with open(path, "w") as f:
        json.dump({
            "p": r4(v), "n": r4(nrm, 3), "i": [int(x) for x in tris.ravel()],
            "j": [int(x) for x in J.ravel()], "w": r4(W, 3),
            "vessels": {"p": r4(VP), "n": r4(VN, 3), "u": r4(VU, 4), "i": [int(x) for x in np.array(vessels_f).ravel()],
                        "j": [int(x) for x in VJ.ravel()], "w": r4(VW, 3), "length": round(float(VU[:, 0].max()), 3)},
            "bones": [{"name": b, "parent": index[bones[b]["parent"]] if bones[b]["parent"] else -1,
                       "head": r4(head[b]), "tail": r4(tail[b])} for b in order],
            "heart": r4(heart),
        }, f, separators=(",", ":"))
    print(f"{len(v)} vertices, {len(tris)} triangles, {len(order)} bones, vessels {len(VP)} vertices / {len(vessels_f)} triangles -> {path} ({os.path.getsize(path) // 1024} KB)")
    print(f"  heart [{heart[0]:.3f}, {heart[1]:.3f}, {heart[2]:.3f}]   longest vessel {VU[:, 0].max():.2f} m")

    # landmarks for the anchors (model space; +x is the screen's right when it faces you)
    def front(sel):
        p = v[sel]
        return p[np.argmax(p[:, 2])]
    def near(y, x=0.0, dy=0.015, dx=0.03):
        return (np.abs(v[:, 1] - y) < dy) & (np.abs(v[:, 0] - x) < dx)
    top = v[:, 1].max()
    marks = {
        "forehead": front(near(top - 0.09)),
        "eye (left of screen)": front(near(top - 0.14, -0.033)),
        "chin": front(near(top - 0.23)),
        "heart": front(near(1.33, 0.05)),
        "belly": front(near(1.08, -0.06)),
        "navel": front(near(1.0, 0.0)),
        "neck": front(near(top - 0.29)),
        "upper arm (right)": v[np.argmin(np.abs(v[:, 0] - 0.3) + np.abs(v[:, 1] - 1.28) * 2)],
        "hand (right)": v[v[:, 0] > v[:, 0].max() - 0.08].mean(axis=0),
        "thigh (left)": front(near(0.72, -0.12)),
        "knee (right)": front(near(0.5, 0.11)),
        "ribs (right)": front(near(1.25, 0.11)),
    }
    for k, p in marks.items():
        print(f"  {k:22} [{p[0]:.3f}, {p[1]:.3f}, {p[2]:.3f}]")


if __name__ == "__main__":
    main()
