.pragma library
// The hologram's skeleton, posed: quaternions are [w, x, y, z] arrays, positions [x, y, z]. Each bone's
// rest frame is unturned and sits at its head, so a bone's skinning transform is just its global turn
// about its rest head, moved to where that head is now (see Ripperdoc's Skin).

function mul(a, b) {
    return [a[0] * b[0] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3],
            a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2],
            a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1],
            a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0]];
}
function rot(q, v) {
    // v + 2 u × (u × v + w v)
    const ux = q[1], uy = q[2], uz = q[3], w = q[0];
    const cx = uy * v[2] - uz * v[1] + w * v[0];
    const cy = uz * v[0] - ux * v[2] + w * v[1];
    const cz = ux * v[1] - uy * v[0] + w * v[2];
    return [v[0] + 2 * (uy * cz - uz * cy), v[1] + 2 * (uz * cx - ux * cz), v[2] + 2 * (ux * cy - uy * cx)];
}
function axis(x, y, z, deg) {
    const h = deg * Math.PI / 360, s = Math.sin(h);
    return [Math.cos(h), x * s, y * s, z * s];
}
function slerp(a, b, t) {
    let d = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
    const s = d < 0 ? -1 : 1;
    d *= s;
    if (d > 0.9995) {
        const r = [a[0] + (s * b[0] - a[0]) * t, a[1] + (s * b[1] - a[1]) * t, a[2] + (s * b[2] - a[2]) * t, a[3] + (s * b[3] - a[3]) * t];
        const n = Math.hypot(r[0], r[1], r[2], r[3]);
        return [r[0] / n, r[1] / n, r[2] / n, r[3] / n];
    }
    const th = Math.acos(d), sn = Math.sin(th);
    const ka = Math.sin((1 - t) * th) / sn, kb = s * Math.sin(t * th) / sn;
    return [a[0] * ka + b[0] * kb, a[1] * ka + b[1] * kb, a[2] * ka + b[2] * kb, a[3] * ka + b[3] * kb];
}

// every bone's local turn in a compiled pose (rig/poses.json: unlisted bones don't turn)
function locals(pose, n) {
    const out = new Array(n);
    for (let i = 0; i < n; i++) out[i] = pose.q[i] ?? [1, 0, 0, 0];
    return out;
}

// forward kinematics: global turns G and head positions P of every bone (parents come first)
function solve(bones, local, hips) {
    const n = bones.length, G = new Array(n), P = new Array(n);
    for (let i = 0; i < n; i++) {
        const b = bones[i], p = b.parent;
        if (p < 0) {
            G[i] = local[i];
            P[i] = [b.head[0] + hips[0], b.head[1] + hips[1], b.head[2] + hips[2]];
        } else {
            const ph = bones[p].head, o = rot(G[p], [b.head[0] - ph[0], b.head[1] - ph[1], b.head[2] - ph[2]]);
            G[i] = mul(G[p], local[i]);
            P[i] = [P[p][0] + o[0], P[p][1] + o[1], P[p][2] + o[2]];
        }
    }
    return { G: G, P: P };
}

// where a point of the rest body is now, skinned like the body is (`skin`: its four bones and weights)
function place(fk, bones, a, skin) {
    let x = 0, y = 0, z = 0;
    for (let k = 0; k < 4; k++) {
        const w = skin.w[k];
        if (!w) continue;
        const j = skin.j[k], h = bones[j].head;
        const v = rot(fk.G[j], [a[0] - h[0], a[1] - h[1], a[2] - h[2]]);
        x += w * (v[0] + fk.P[j][0]);
        y += w * (v[1] + fk.P[j][1]);
        z += w * (v[2] + fk.P[j][2]);
    }
    return [x, y, z];
}
