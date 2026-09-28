pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The shell's own windows (Control Panel, Properties sheets, Run, Shut Down, Help, the Media Player,
// the Notifications inbox…): which are open, on which screen, where, and in what order.
// DeskLayer draws them. Each window has an id:
//   control   Control Panel            run        Run…               shutdown   Shut Down Windows
//   logoff    Log Off                  help       Windows Help       messages   Notifications inbox
//   media     Media Player             volume     Volume Control     applet:<name>  a Properties sheet
// Applets: datetime display multimedia network system lighting timer claude power
//
// The shared IPC contract, `qs ipc call deck open <page>`, lands here: the other setups' deck pages
// map onto Control Panel applets and tabs (see `pages`).
Singleton {
    id: root

    property var wins: ({})         // id -> { screen, x, y, z, tab }
    property int topZ: 1
    readonly property var ids: Object.keys(wins)
    readonly property string top: {
        let best = "", z = -1;
        for (const id of ids) if (wins[id].z > z) { z = wins[id].z; best = id; }
        return best;
    }
    // Windows that take the keyboard as soon as they open (typing goes straight in)
    readonly property var grabbers: ["run", "shutdown", "logoff"]
    readonly property bool wantsKeys: grabbers.includes(top)

    // Sizes (the layer centres a window on its first showing)
    function size(id) {
        if (id.startsWith("applet:")) return { w: 520, h: 600 };
        return ({
            control: { w: 860, h: 580 }, run: { w: 480, h: 250 }, shutdown: { w: 440, h: 330 },
            logoff: { w: 380, h: 170 }, help: { w: 640, h: 560 }, messages: { w: 760, h: 520 },
            media: { w: 460, h: 400 }, volume: { w: 620, h: 420 },
        })[id] ?? { w: 480, h: 360 };
    }

    function focusedScreen() { return Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""; }

    function show(id, extra) {
        const w = Object.assign({}, root.wins);
        const cur = w[id];
        const s = size(id);
        w[id] = Object.assign({ screen: focusedScreen(), x: -1, y: -1, w: s.w, h: s.h, tab: "" }, cur ?? {}, extra ?? {},
                              { z: ++topZ });
        wins = w;
    }
    function close(id) {
        if (!wins[id]) return;
        const w = Object.assign({}, wins);
        delete w[id];
        wins = w;
    }
    function toggle(id, extra) { if (top === id) close(id); else show(id, extra); }
    function raise(id) {
        if (!wins[id] || wins[id].z === topZ) return;
        const w = Object.assign({}, wins);
        w[id] = Object.assign({}, w[id], { z: ++topZ });
        wins = w;
    }
    function moveTo(id, x, y) {
        if (!wins[id]) return;
        const w = Object.assign({}, wins);
        w[id] = Object.assign({}, w[id], { x: Math.round(x), y: Math.round(y) });
        wins = w;
    }
    function resize(id, w, h) {
        if (!wins[id] || (wins[id].w === w && wins[id].h === h)) return;
        const n = Object.assign({}, wins);
        n[id] = Object.assign({}, n[id], { w: Math.round(w), h: Math.round(h) });
        wins = n;
    }
    function setTab(id, tab) {
        if (!wins[id]) return;
        const w = Object.assign({}, wins);
        w[id] = Object.assign({}, w[id], { tab: tab });
        wins = w;
    }
    function isOpen(id) { return wins[id] !== undefined; }

    // ---------------------------------------------------------------- deck pages -> applets
    // helm = Control Panel (its web-view pane holds the quick switches, levels, capture and power)
    readonly property var pages: ({
        helm: ["control", ""], radio: ["applet:multimedia", "Now Playing"], log: ["messages", ""],
        almanac: ["applet:datetime", "Date & Time"], telemetry: ["applet:system", "Performance"],
        hangar: ["applet:system", "Device Manager"], optics: ["applet:display", "Settings"],
        lamps: ["applet:lighting", ""], chronometer: ["applet:timer", ""], comms: ["applet:network", "Wi-Fi"],
        claude: ["applet:claude", ""],
    })
    function openPage(page) {
        const p = pages[page] ?? pages.helm;
        show(p[0], p[1] ? { tab: p[1] } : {});
    }

    IpcHandler {
        target: "deck"
        function toggle(): void { root.toggle("control"); }
        function open(page: string): void { root.openPage(page); }
        function close(): void { for (const id of root.ids) root.close(id); }
    }
    IpcHandler {
        target: "run"
        function toggle(): void { root.toggle("run"); }
        function open(): void { root.show("run"); }
        function close(): void { root.close("run"); }
    }
    IpcHandler {
        target: "desk"
        // open any window by id (for testing): qs ipc call desk open applet:display
        function open(id: string): void { root.show(id); }
        function close(id: string): void { root.close(id); }
        function list(): string { return root.ids.join(" "); }
    }
}
