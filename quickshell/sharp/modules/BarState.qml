pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bar auto-hide state shared by every monitor's bar
Singleton {
    id: root

    // Keep the bar open instead of hiding it
    property bool pinned: false

    // qs ipc call bar toggle
    IpcHandler {
        target: "bar"
        function toggle(): void { root.pinned = !root.pinned; }
    }

    // The control panel, by the page names every setup shares (Observatory's deck pages):
    //   qs ipc call deck open <page> | toggle | close
    // Each monitor's Bar listens; the one on the focused monitor opens its panel.
    signal panelRequested(string tab, int subPage)
    signal panelToggleRequested()
    signal panelCloseRequested()

    readonly property var deckPages: ({
        helm: ["Quick", -1], radio: ["Media", -1], log: ["Quick", -1], almanac: ["Weather", -1],
        telemetry: ["Stats", -1], hangar: ["Devices", -1], optics: ["Display", -1], lamps: ["RGB", -1],
        chronometer: ["Focus", -1], comms: ["Settings", 0], claude: ["Claude", -1],
    })

    IpcHandler {
        target: "deck"
        function open(page: string): void {
            const key = page.toLowerCase();
            const hit = root.deckPages[key] ?? [page.charAt(0).toUpperCase() + page.slice(1), -1];
            root.panelRequested(hit[0], hit[1]);
        }
        function toggle(): void { root.panelToggleRequested(); }
        function close(): void { root.panelCloseRequested(); }
    }
}
