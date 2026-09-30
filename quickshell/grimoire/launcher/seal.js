// Seals for programs, after the idea of the glyphs in Witch Hat Atelier: a seal is not a word
// spelled out but a composition, and every part of it means something.
//
//   the sigil, in the middle     what kind of thing the program is (its element), from its categories:
//                                fire     making: development, graphics, building
//                                water    what flows between people: the web, chat, mail, the network
//                                wind     what moves through the air: sound, music, video
//                                earth    the ground under everything: files, the system, terminals, settings
//                                light    what is read and learned: documents, office, science, play
//   the signs, round it          what the program does, from its name, description and keywords:
//                                column       it sends something out, directed (commands, writing, browsing)
//                                dispersion   it spreads things wide (sharing, messages, streams)
//                                convergence  it gathers things in (files, libraries, viewers, downloads)
//                                levitation   it holds things lightly in hand (settings, tools, controls)
//                                cycle        it turns and repeats (players, recorders, games)
//                                ward         it guards (passwords, keys, security)
//                                weave        none of these: plain craft
//   how many times they repeat   the symmetry grows with the name: a short name, a simple seal
//   the tick band                four ticks for every letter of its name
//   the binding points           a dot between each pair of signs, where their powers meet
//   the rings                    a ring holds the sigil, a band holds the signs, and the outer ring
//                                completes the seal; a seal used often is drawn stronger: a second
//                                ring round the sigil after 5 summonings, a second outer ring after 20
//
// make(app, uses) returns { strokes: [{ pts: [[x, y]…], w, part }], element, signs, fold, rings }
// on a 200 × 200 field centred on (100, 100). Strokes are in drawing order: sigil, inner ring,
// signs, ticks, outer rings (the very last stroke is the ring that closes the seal).

const C = 100;

function arc(cx, cy, r, a0, a1, n) {
    const out = [];
    const k = n ?? Math.max(8, Math.ceil(Math.abs(a1 - a0) * r / 3));
    for (let i = 0; i <= k; i++) {
        const a = a0 + (a1 - a0) * i / k;
        out.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    }
    return out;
}
function circle(cx, cy, r, start) {
    const s = start ?? -Math.PI / 2;
    return arc(cx, cy, r, s, s + 2 * Math.PI);
}
function line(x0, y0, x1, y1) { return [[x0, y0], [x1, y1]]; }

// ---------------------------------------------------------------- the sigils
const SIGILS = {
    fire: () => {
        // a flame: a teardrop pointed at the top, a smaller one inside it, and the hearth under it
        const drop = (sx, sy, dy) => {
            const pts = [];
            for (let i = 0; i <= 48; i++) {
                const t = i / 48 * 2 * Math.PI;
                pts.push([C + sx * Math.sin(t) * Math.sin(t / 2), C + dy - sy * Math.cos(t)]);
            }
            return pts;
        };
        return [drop(20, 27, -2), drop(9, 12, 12), line(84, 134, 116, 134)];
    },
    water: () => {
        // a lens of two arcs, three waves inside
        const lens = arc(C, C + 38, 52, -Math.PI / 2 - 0.72, -Math.PI / 2 + 0.72).concat(arc(C, C - 38, 52, Math.PI / 2 - 0.72, Math.PI / 2 + 0.72));
        const wave = y => { const p = []; for (let x = 76; x <= 124; x += 2) p.push([x, y + Math.sin((x - 76) / 48 * 2 * Math.PI) * 3.5]); return p; };
        return [lens, wave(92), wave(100), wave(108)];
    },
    wind: () => {
        // a spiral opening outwards, and the gust leaving it
        const sp = [];
        for (let i = 0; i <= 90; i++) {
            const t = i / 90 * 2.6 * Math.PI;
            const r = 3 + t * 3.4;
            sp.push([C + Math.cos(t - Math.PI / 2) * r, C + Math.sin(t - Math.PI / 2) * r]);
        }
        const end = sp[sp.length - 1];
        return [sp, [end, [end[0] + 16, end[1] + 2]], line(C - 26, C + 24, C + 10, C + 24)];
    },
    earth: () => {
        // a standing stone: a diamond, the ground across it, a root down from it
        return [
            [[C, 70], [128, C], [C, 130], [72, C], [C, 70]],
            line(66, C, 134, C),
            line(C, 110, C, 138),
        ];
    },
    light: () => {
        // a sun: a small disc and eight rays, long and short
        const out = [circle(C, C, 9)];
        for (let k = 0; k < 8; k++) {
            const a = k / 8 * 2 * Math.PI - Math.PI / 2;
            const r1 = 14, r2 = k % 2 ? 23 : 31;
            out.push(line(C + Math.cos(a) * r1, C + Math.sin(a) * r1, C + Math.cos(a) * r2, C + Math.sin(a) * r2));
        }
        return out;
    },
};

// ---------------------------------------------------------------- the signs
// each in its own frame: u runs outwards from the sigil, v across; drawn from u = 0
const SIGNS = {
    column: () => [line(0, 0, 22, 0), line(22, -6, 22, 6)],
    dispersion: () => [line(0, 0, 20, -9), line(0, 0, 23, 0), line(0, 0, 20, 9)],
    convergence: () => [[[22, -9], [5, 0], [22, 9]], line(12, 0, 22, 0)],
    levitation: () => [arc(9, 0, 9, -Math.PI / 2, Math.PI / 2, 16), circle(3, 0, 2.2)],
    cycle: () => [circle(11, 0, 7, Math.PI), line(18, 0, 24, 0)],
    ward: () => [[[19, -9], [4, -9], [4, 9], [19, 9]], line(10, 0, 19, 0)],
    weave: () => [[[0, 0], [6, -5], [12, 5], [18, -5], [24, 0]]],
};
const TRAITS = [
    ["ward", /password|secur|keyring|\bkeys?\b|vpn|firewall|encrypt|\block\b|auth|secret/],
    ["cycle", /\bplay|music|audio|video|media|player|record|game|podcast|radio|stream/],
    ["dispersion", /shar|torrent|network|chat|messag|mail|social|broadcast|upload|sync|remote|ssh|vnc/],
    ["convergence", /file|folder|archive|download|collect|librar|manag|view|reader|image|photo|gallery|book/],
    ["column", /terminal|shell|command|editor|\bcode\b|\bide\b|write|compos|brows|web|search|launch/],
    ["levitation", /setting|config|prefer|tweak|control|tool|utilit|monitor|about|information/],
];
const ELEMENTS = [
    ["wind", /audiovideo|audio|video|player|music|recorder|tv/],
    ["water", /network|webbrowser|chat|email|instantmessaging|p2p|filetransfer|telephony|remoteaccess/],
    ["fire", /development|graphics|ide|building|debugger|2dgraphics|3dgraphics|vectorgraphics|rastergraphics|photography/],
    ["light", /office|education|science|viewer|documentation|wordprocessor|spreadsheet|presentation|game|dictionary/],
    ["earth", /system|utility|filemanager|settings|terminalemulator|monitor|packagemanager|archiving|filesystem|security/],
];
const ORDER = ["fire", "water", "wind", "earth", "light"];

function hash(s) {
    let h = 2166136261;
    for (const ch of s) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); }
    return h >>> 0;
}

function elementOf(app) {
    const cats = (app.categories ?? []).join(" ").toLowerCase();
    for (const [el, re] of ELEMENTS) if (re.test(cats)) return el;
    // no categories to go on: what it says about itself, then its name
    const words = [app.genericName ?? "", app.comment ?? ""].join(" ").toLowerCase();
    for (const [el, re] of ELEMENTS) if (re.test(words)) return el;
    return ORDER[hash(app.id ?? app.name ?? "") % ORDER.length];
}
function signsOf(app) {
    const text = [app.name, app.genericName, app.comment, (app.keywords ?? []).join(" "), (app.categories ?? []).join(" ")]
        .join(" ").toLowerCase();
    const found = [];
    for (const [sign, re] of TRAITS) if (re.test(text)) found.push(sign);
    return found.length ? found.slice(0, 3) : ["weave"];
}

function make(app, uses) {
    const name = (app?.name ?? "").trim();
    const letters = name.replace(/[^A-Za-z0-9]/g, "").length || 1;
    const element = elementOf(app ?? {});
    const signs = signsOf(app ?? {});
    const u = uses ?? 0;

    // the symmetry: a multiple of the number of signs, as near the name's length as fits 4 .. 8
    const k = signs.length;
    let fold = k;
    for (let m = 1; m * k <= 8; m++) if (m * k >= 3 && Math.abs(m * k - Math.min(8, Math.max(4, letters))) <= Math.abs(fold - Math.min(8, Math.max(4, letters)))) fold = m * k;
    if (fold < 3) fold = k * Math.ceil(3 / k);
    // the first letter turns the seal a little, so seals of the same kind still differ
    const turn = ((name.charCodeAt(0) || 65) % 12) / 12 * (2 * Math.PI / fold);

    const strokes = [];
    const big = 1.15;
    for (const p of SIGILS[element]()) strokes.push({ pts: p.map(([x, y]) => [C + (x - C) * big, C + (y - C) * big]), w: 2.5, part: "sigil" });
    const rings = u >= 20 ? 3 : u >= 5 ? 2 : 1;
    strokes.push({ pts: circle(C, C, 43), w: 1.3, part: "inner" });
    if (rings >= 2) strokes.push({ pts: circle(C, C, 39.5), w: 0.9, part: "inner" });

    const R0 = 47, SS = 1.3;
    for (let i = 0; i < fold; i++) {
        const a = -Math.PI / 2 + turn + i / fold * 2 * Math.PI;
        const ca = Math.cos(a), sa = Math.sin(a);
        for (const p of SIGNS[signs[i % k]]())
            strokes.push({ pts: p.map(([pu, pv]) => [C + ca * (R0 + pu * SS) - sa * pv * SS, C + sa * (R0 + pu * SS) + ca * pv * SS]), w: 2.0, part: "sign" });
    }
    // the binding points, between the signs
    for (let i = 0; i < fold; i++) {
        const a = -Math.PI / 2 + turn + (i + 0.5) / fold * 2 * Math.PI;
        strokes.push({ pts: circle(C + Math.cos(a) * 66, C + Math.sin(a) * 66, 1.6), w: 1.6, part: "point" });
    }
    strokes.push({ pts: circle(C, C, 83), w: 1.3, part: "band" });

    const nt = Math.min(64, letters * 4);
    for (let i = 0; i < nt; i++) {
        const a = -Math.PI / 2 + (i + 0.5) / nt * 2 * Math.PI;
        strokes.push({ pts: line(C + Math.cos(a) * 85.5, C + Math.sin(a) * 85.5, C + Math.cos(a) * (i % 4 ? 89 : 90.5), C + Math.sin(a) * (i % 4 ? 89 : 90.5)), w: 1.1, part: "tick" });
    }
    if (rings >= 3) strokes.push({ pts: circle(C, C, 98), w: 1.1, part: "ring" });
    strokes.push({ pts: circle(C, C, 94.5), w: 2.6, part: "ring" });

    for (const s of strokes) {
        let len = 0;
        for (let i = 1; i < s.pts.length; i++) len += Math.hypot(s.pts[i][0] - s.pts[i - 1][0], s.pts[i][1] - s.pts[i - 1][1]);
        s.len = len;
    }
    return { strokes: strokes, element: element, signs: signs, fold: fold, rings: rings, letters: letters };
}

// the first `frac` of a stroke's length, as an SVG path
function partial(s, frac) {
    const pts = s.pts;
    if (frac <= 0 || pts.length < 2) return "";
    let want = s.len * Math.min(1, frac);
    let d = `M ${pts[0][0].toFixed(2)} ${pts[0][1].toFixed(2)}`;
    for (let i = 1; i < pts.length; i++) {
        const seg = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
        if (seg >= want) {
            const t = seg > 0 ? want / seg : 0;
            d += ` L ${(pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * t).toFixed(2)} ${(pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * t).toFixed(2)}`;
            return d;
        }
        want -= seg;
        d += ` L ${pts[i][0].toFixed(2)} ${pts[i][1].toFixed(2)}`;
    }
    return d;
}
