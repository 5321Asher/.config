pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// The rig: Netrunner's control panel, drawn as a ripperdoc's cyberware screen (rig/Ripperdoc.qml).
// Its pages are the shared deck pages (what `qs ipc call deck open <page>` names in every setup):
//   helm radio log almanac telemetry hangar optics lamps chronometer comms claude
// and each one is an implant slot on the hologram body: `slot` its name, `anchor` where it sits on
// the body (metres, model space: feet at 0, facing +z), `side` which column its card goes in.
// page "" is the overview (the body and every slot); a page name opens that slot.
Singleton {
    id: root

    property bool open: false
    property string page: ""
    property bool fromOverview: false        // Esc goes back to the body (else it closes the rig)
    property string status: ""               // the rig's state, for tests: qs ipc call deck state

    // The game's eleven cyberware categories, six down the left and five down the right as on its
    // screen. glyph: the implant's icon; tier: its rarity, as the game colours items (LEGENDARY gold,
    // EPIC violet, RARE blue-cyan, UNCOMMON green); row: how far down the screen its row sits (0..1);
    // indent: its row pulled in towards the body by this many slots.
    readonly property var pages: [
        { id: "claude", code: "01", title: "claude", jp: "前頭皮質", slot: "frontal cortex", sub: "account // usage // limits", anchor: [0.0, 1.7, 0.094], side: 0, row: 0.2, indent: 0,
          glyph: "\u{f09d1}", tier: "legendary", desc: "The co-processor. How much of the session is spent, and when it resets." },
        { id: "optics", code: "02", title: "optics", jp: "眼球系", slot: "ocular system", sub: "screens // layout // brightness", anchor: [-0.033, 1.645, 0.09], side: 0, row: 0.3, indent: 1,
          glyph: "\u{f0208}", tier: "epic", desc: "Kiroshi optics: every screen, its layout and its light." },
        { id: "telemetry", code: "03", title: "telemetry", jp: "循環系", slot: "circulatory system", sub: "cpu // gpu // memory // net", anchor: [0.06, 1.318, 0.09], side: 0, row: 0.45, indent: 0,
          glyph: "\u{f05f6}", tier: "epic", desc: "What the rig's heart is pumping: processors, memory, storage, network." },
        { id: "log", code: "04", title: "log", jp: "免疫系", slot: "immune system", sub: "messages // do not disturb", anchor: [-0.034, 1.081, 0.08], side: 0, row: 0.575, indent: 0,
          glyph: "\u{f011c}", tier: "rare", desc: "What gets in: every message that came, and whether they're let through." },
        { id: "comms", code: "05", title: "comms", jp: "神経系", slot: "nervous system", sub: "wi-fi // bluetooth // tailscale", anchor: [-0.019, 0.987, 0.082], side: 0, row: 0.68, indent: 0,
          glyph: "\u{f05a9}", tier: "epic", desc: "Every link out: wireless, bluetooth, the tailnet and its exit." },
        { id: "almanac", code: "06", title: "almanac", jp: "外皮系", slot: "integumentary system", sub: "calendar // weather // moon", anchor: [-0.126, 0.706, 0.045], side: 0, row: 0.79, indent: 0,
          glyph: "\u{f0595}", tier: "uncommon", desc: "What the skin feels: the weather, the week, the moon." },
        { id: "helm", code: "07", title: "helm", jp: "OS", slot: "operating system", sub: "switches // levels // capture // power", anchor: [0.0, 1.53, 0.05], side: 1, row: 0.31, indent: 0,
          glyph: "\u{f061a}", tier: "legendary", desc: "The deck's OS: the everyday switches, the levels, capture and power." },
        { id: "hangar", code: "08", title: "hangar", jp: "骨格", slot: "skeleton", sub: "drives // batteries // fans", anchor: [0.1, 1.258, 0.073], side: 1, row: 0.5, indent: 0,
          glyph: "\u{f068c}", tier: "uncommon", desc: "The frame: drives, batteries, fans." },
        { id: "lamps", code: "09", title: "lamps", jp: "手", slot: "hands", sub: "rgb // follow profile", anchor: [0.506, 1.066, 0.202], side: 1, row: 0.6, indent: 0,
          glyph: "\u{f0a4f}", tier: "rare", desc: "The lights on the rig's hands: colour, profiles, following the profile." },
        { id: "radio", code: "10", title: "radio", jp: "腕", slot: "arms", sub: "now playing // mixer // devices", anchor: [0.308, 1.281, -0.013], side: 1, row: 0.69, indent: 0,
          glyph: "\u{f07c5}", tier: "rare", desc: "Audio in and out: what's playing, every app's level, the devices." },
        { id: "chronometer", code: "11", title: "chrono", jp: "脚", slot: "legs", sub: "focus // pomodoro // timer", anchor: [0.127, 0.499, 0.02], side: 1, row: 0.79, indent: 0,
          glyph: "\u{f06ad}", tier: "legendary", desc: "Run faster than time: focus rounds, breaks, a plain timer." },
    ]
    function tierColor(t) {
        return t === "legendary" ? Theme.yellow : t === "epic" ? Qt.hsla(0.78, 0.75, 0.68, 1) : t === "rare" ? Theme.cyan : Theme.green;
    }
    readonly property var current: pages.find(p => p.id === page) ?? null

    // Opening always shows the whole body with nothing selected; a page named when opening (the bar's
    // readouts, the menus) is only lit up there (`highlight`). Once open, naming a page selects it.
    property string highlight: ""
    function show(p) {
        const known = pages.some(x => x.id === p);
        if (open) { if (known) page = p; return; }
        page = "";
        highlight = known ? p : "";
        open = true;
    }
    function toggleTo(p) {
        if (open) open = false;
        else show(p);
    }

    // The hologram (rig/body.json and rig/poses.json, made by setups/netrunner/body.py and poses.py),
    // read once: Ripperdoc's 3D view is rebuilt on every open and takes these ready-made.
    // The body and its vessels are skinned to `bones` ({parent, head}); `poses` are compiled poses
    // ({hips, q: {bone: quaternion}}), `posePages` which one each page strikes.
    property var bodyPositions: []
    property var bodyNormals: []
    property var bodyIndexes: []
    property var bodyJoints: []
    property var bodyWeights: []
    property var vessels: null               // positions normals uvs (distance from the heart, radius) indexes joints weights
    property var bones: []
    property var inverseBinds: []
    property var heart: [0.03, 1.26, 0.016]
    property var anchorSkin: ({})            // page -> the bones (and weights) its anchor rides on
    property var poses: ({})
    property var posePages: ({})
    FileView {
        path: Quickshell.shellDir + "/rig/body.json"
        printErrors: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                const v2 = a => { const o = []; for (let i = 0; i < a.length; i += 2) o.push(Qt.vector2d(a[i], a[i + 1])); return o; };
                const v3 = a => { const o = []; for (let i = 0; i < a.length; i += 3) o.push(Qt.vector3d(a[i], a[i + 1], a[i + 2])); return o; };
                const v4 = a => { const o = []; for (let i = 0; i < a.length; i += 4) o.push(Qt.vector4d(a[i], a[i + 1], a[i + 2], a[i + 3])); return o; };
                const sk = {};
                for (const pg of root.pages) {
                    let best = 0, bd = 1e9;
                    for (let i = 0; i < d.p.length; i += 3) {
                        const dd = (d.p[i] - pg.anchor[0]) ** 2 + (d.p[i + 1] - pg.anchor[1]) ** 2 + (d.p[i + 2] - pg.anchor[2]) ** 2;
                        if (dd < bd) { bd = dd; best = i / 3; }
                    }
                    sk[pg.id] = { j: d.j.slice(best * 4, best * 4 + 4), w: d.w.slice(best * 4, best * 4 + 4) };
                }
                root.anchorSkin = sk;
                root.bones = d.bones.map(b => ({ name: b.name, parent: b.parent, head: b.head }));
                root.inverseBinds = d.bones.map(b => Qt.matrix4x4(1, 0, 0, -b.head[0], 0, 1, 0, -b.head[1], 0, 0, 1, -b.head[2], 0, 0, 0, 1));
                root.heart = d.heart;
                const V = d.vessels;
                root.vessels = { positions: v3(V.p), normals: v3(V.n), uvs: v2(V.u), indexes: V.i, joints: v4(V.j), weights: v4(V.w), length: V.length };
                root.bodyJoints = v4(d.j);
                root.bodyWeights = v4(d.w);
                root.bodyNormals = v3(d.n);
                root.bodyIndexes = d.i;
                root.bodyPositions = v3(d.p);
            } catch (e) {
                console.warn("rig body:", e);
            }
        }
    }
    FileView {
        path: Quickshell.shellDir + "/rig/poses.json"
        printErrors: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.poses = d.poses;
                root.posePages = d.pages;
            } catch (e) {
                console.warn("rig poses:", e);
            }
        }
    }

    IpcHandler {
        target: "deck"
        function toggle(): void { if (root.open) root.open = false; else root.show(""); }
        function open(page: string): void { root.show(page); }
        function close(): void { root.open = false; }
        function state(): string { return root.status; }
    }
}
