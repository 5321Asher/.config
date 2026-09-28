pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The codex: Grimoire's control panel, an open book. Its chapters are the shared deck pages (what
// `qs ipc call deck open <page>` names in every setup), renamed for the book:
//   helm Sanctum · comms Sendings · radio Minstrelsy · log Letters · almanac Almanac ·
//   telemetry Alchemy · hangar Reliquary · optics Scrying · lamps Lanterns ·
//   chronometer Hourglass · claude Familiar
Singleton {
    id: root

    property bool open: false
    property string page: "helm"
    // which way the last page turned (1 = forward), for the page-turn animation
    property int turning: 1

    readonly property var pages: [
        { id: "helm", title: "Sanctum", sub: "switches · levels · capture · power", glyph: "\u{f0493}" },
        { id: "comms", title: "Sendings", sub: "wi-fi · bluetooth · tailscale", glyph: "\u{f05a9}" },
        { id: "radio", title: "Minstrelsy", sub: "now playing · the mixer · devices", glyph: "\u{f075a}" },
        { id: "log", title: "Letters", sub: "every letter kept · do not disturb", glyph: "\u{f01ee}" },
        { id: "almanac", title: "Almanac", sub: "the month · the weather · the moon", glyph: "\u{f0f64}" },
        { id: "telemetry", title: "Alchemy", sub: "reagents · memory · disks · wards", glyph: "\u{f0093}" },
        { id: "hangar", title: "Reliquary", sub: "batteries · drives · fans", glyph: "\u{f01bc}" },
        { id: "optics", title: "Scrying", sub: "screens · layout · brightness", glyph: "\u{f0379}" },
        { id: "lamps", title: "Lanterns", sub: "coloured light · follow the theme", glyph: "\u{f0335}" },
        { id: "chronometer", title: "Hourglass", sub: "focus · pomodoro · countdown", glyph: "\u{f051f}" },
        { id: "claude", title: "Familiar", sub: "your claude · usage · limits", glyph: "\u{f06a9}" },
    ]
    readonly property int index: Math.max(0, pages.findIndex(p => p.id === page))
    readonly property var current: pages[index]

    function turnTo(p) {
        const i = pages.findIndex(x => x.id === p);
        if (i < 0 || p === page) return;
        turning = i > index ? 1 : -1;
        page = p;
    }
    function show(p) {
        if (!open) { if (pages.some(x => x.id === p)) page = p; }
        else turnTo(p);
        open = true;
    }
    function toggleTo(p) {
        if (open && page === p) open = false;
        else show(p);
    }
    function step(d) { turnTo(pages[(index + d + pages.length) % pages.length].id); }

    IpcHandler {
        target: "deck"
        function toggle(): void { root.open = !root.open; }
        function open(page: string): void { root.show(page); }
        function close(): void { root.open = false; }
    }
}
