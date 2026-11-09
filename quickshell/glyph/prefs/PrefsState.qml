pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../quick"

// Settings: Glyph's control panel, a column of dot-matrix words (the selected one big, with the red
// dot) and its page. The pages are the shared deck pages (what `qs ipc call deck open <page>` names
// in every setup); helm, the everyday switches, is the quick settings panel instead.
//   helm radio log almanac telemetry hangar optics lamps chronometer comms claude
Singleton {
    id: root

    property bool open: false
    property string page: "comms"

    readonly property var pages: [
        { id: "comms", word: "NETWORK", sub: "wi-fi · bluetooth · tailscale" },
        { id: "radio", word: "SOUND", sub: "now playing · mixer · devices" },
        { id: "log", word: "NOTES", sub: "notifications · do not disturb" },
        { id: "almanac", word: "CALENDAR", sub: "month · weather · moon" },
        { id: "telemetry", word: "SYSTEM", sub: "cpu · gpu · memory · security" },
        { id: "hangar", word: "DEVICES", sub: "drives · batteries · fans" },
        { id: "optics", word: "DISPLAY", sub: "screens · layout · profiles" },
        { id: "lamps", word: "LIGHTS", sub: "rgb · follow the theme" },
        { id: "chronometer", word: "FOCUS", sub: "focus · pomodoro" },
        { id: "claude", word: "CLAUDE", sub: "account · usage · limits" },
    ]
    readonly property int index: Math.max(0, pages.findIndex(p => p.id === page))
    readonly property var current: pages[index]

    function show(p) {
        if (p === "helm") { open = false; QuickState.open = true; return; }
        if (pages.some(x => x.id === p)) page = p;
        open = true;
    }
    function step(d) { page = pages[(index + d + pages.length) % pages.length].id; }

    IpcHandler {
        target: "deck"
        function toggle(): void { root.open = !root.open; }
        function open(page: string): void { root.show(page); }
        function close(): void { root.open = false; QuickState.open = false; }
    }
}
