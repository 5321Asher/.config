pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../flyouts"

// Alt + Tab, as Windows 11 does it: the windows on this desktop (and minimised ones), most recently
// used first, the first press already on the one before. Hold Alt and press Tab to move on (Shift
// back), let go of Alt to switch; Esc cancels. A quick tap switches straight away without showing the
// switcher (it only appears after a moment). Hyprland binds (setup-binds.lua):
//   ALT + Tab -> alttab next, ALT + SHIFT + Tab -> alttab prev, releasing Alt -> alttab commit
Singleton {
    id: root

    property bool active: false         // Alt is held, a switch is under way
    property bool shown: false          // …and the switcher is on screen
    property var wins: []
    property int sel: 0
    property string screenName: ""

    // Most recently used first, kept live from Hyprland's active window (Hyprland's own
    // focusHistoryID comes from a cached query that is often stale: Alt + Tab then "switched" to the
    // window already in front and seemed to do nothing)
    property var mru: []
    function touch(t) { if (t) mru = [t.address].concat(mru.filter(a => a !== t.address)).slice(0, 200); }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root.touch(Hyprland.activeToplevel); }
    }
    Component.onCompleted: touch(Hyprland.activeToplevel)

    function snapshot() {
        const ws = Hyprland.focusedWorkspace?.id;
        const list = Hyprland.toplevels.values.filter(t => t.workspace?.id === ws || Apps.isMin(t));
        const active = Hyprland.activeToplevel;
        const rank = t => t === active ? -1 : (i => i < 0 ? 999 + (t.lastIpcObject?.focusHistoryID ?? 0) : i)(mru.indexOf(t.address));
        return list.sort((a, b) => (Apps.isMin(a) - Apps.isMin(b)) || (rank(a) - rank(b)));
    }
    function step(d) {
        if (!active) {
            wins = snapshot();
            if (wins.length === 0) return;
            screenName = Hyprland.focusedMonitor?.name ?? "";
            sel = wins.length > 1 ? (d > 0 ? 1 : wins.length - 1) : 0;
            active = true;
            showLater.restart();
            return;
        }
        const n = wins.length;
        if (n > 0) sel = (sel + d + n) % n;
        shown = true;
    }
    function commit() {
        if (!active) return;
        const t = wins[sel];
        cancel();
        if (!t) return;
        if (Apps.isMin(t)) Apps.restore(t, Hyprland.focusedWorkspace?.id);
        else Apps.focusWin(t);
    }
    function cancel() {
        showLater.stop();
        active = false;
        shown = false;
    }
    Timer { id: showLater; interval: 140; onTriggered: if (root.active) root.shown = true }

    IpcHandler {
        target: "alttab"
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function commit(): void { root.commit(); }
        function cancel(): void { root.cancel(); }
    }
}
