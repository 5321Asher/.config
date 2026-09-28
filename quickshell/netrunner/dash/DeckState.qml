pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Opening and closing the deck (special:deck). The deck never opens empty: if nothing is on it,
// opening it starts a terminal there (kitty --class netrunner-deck; look.lua sends that class to
// special:deck), which fills the space and is the thing to close: when the last window on the deck
// closes, Hyprland puts the deck away. If something is already there, it just toggles.
//   qs ipc call dash toggle | open | close
Singleton {
    id: root

    readonly property var deckWs: Hyprland.workspaces.values.find(w => w.name === "special:deck") ?? null
    readonly property int windows: deckWs?.toplevels?.values?.length ?? 0
    readonly property bool shown: (Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? "") === "special:deck"

    function refresh() { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces(); }

    function open() {
        refresh();
        if (shown) return;
        if (windows > 0) Hyprland.dispatch(`hl.dsp.workspace.toggle_special("deck")`);
        else Quickshell.execDetached(["kitty", "--class", "netrunner-deck"]);
        later.restart();
    }
    function close() {
        refresh();
        if (shown) Hyprland.dispatch(`hl.dsp.workspace.toggle_special("deck")`);
        later.restart();
    }
    function toggle() { refresh(); if (shown) close(); else open(); }
    Timer { id: later; interval: 150; onTriggered: root.refresh() }

    IpcHandler {
        target: "dash"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }
}
