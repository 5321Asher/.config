pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The control deck: which page is showing and whether it's open.
//   qs ipc call deck toggle | open <page> | close
// Pages: helm, radio, log, almanac, telemetry, hangar, optics, lamps, chronometer, comms, claude
Singleton {
    id: root

    property bool open: false
    property string page: "helm"

    readonly property var pages: [
        { id: "helm", file: "Helm", glyph: "\u{f0493}", title: "helm", sub: "toggles · levels · capture · power" },
        { id: "radio", file: "Media", glyph: "\u{f075a}", title: "radio", sub: "now playing · volume · outputs" },
        { id: "log", file: "Log", glyph: "\u{f09aa}", title: "transmission log", sub: "notification history" },
        { id: "almanac", file: "Almanac", glyph: "\u{f00ed}", title: "almanac", sub: "calendar · weather" },
        { id: "telemetry", file: "Telemetry", glyph: "\u{f0128}", title: "telemetry", sub: "cpu · gpu · memory · network" },
        { id: "hangar", file: "Hangar", glyph: "\u{f02ca}", title: "hangar", sub: "batteries · drives · fans" },
        { id: "optics", file: "Optics", glyph: "\u{f0379}", title: "optics", sub: "displays · layout · brightness" },
        { id: "lamps", file: "Lamps", glyph: "\u{f0335}", title: "lamps", sub: "rgb lighting" },
        { id: "chronometer", file: "Chronometer", glyph: "\u{f13ab}", title: "chronometer", sub: "focus · pomodoro · timer" },
        { id: "comms", file: "Comms", glyph: "\u{f05a9}", title: "comms", sub: "wi-fi · bluetooth · tailscale" },
        { id: "claude", file: "Claude", glyph: "\u{f06a9}", title: "claude", sub: "account · usage · limits" },
    ]
    readonly property var current: pages.find(p => p.id === page) ?? pages[0]

    function show(p) {
        if (pages.some(x => x.id === p)) page = p;
        open = true;
    }
    function toggleTo(p) {
        if (open && page === p) open = false;
        else show(p);
    }

    IpcHandler {
        target: "deck"

        function toggle(): void { root.open = !root.open; }
        function open(page: string): void { root.show(page); }
        function close(): void { root.open = false; }
    }
}
