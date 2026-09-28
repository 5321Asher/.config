import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../widgets"
import "../menus"

// A taskbar button per window on this screen's workspace (plus minimised ones): its icon and
// title, held in (and dithered) for the active window. Click to switch to it; click the active one
// to minimise it (to a hidden special workspace) and again to bring it back; right-click for the
// window menu. Buttons share the space, up to Theme.taskButtonMax each.
Item {
    id: root

    required property HyprlandMonitor monitor
    required property string screenName
    property real screenHeight: 1080
    readonly property string minimized: "special:minimized"

    readonly property var windows: {
        const ws = monitor?.activeWorkspace?.id ?? -1;
        return Hyprland.toplevels.values.filter(t =>
            t.workspace?.id === ws || (t.workspace?.name === minimized && (t.monitor === monitor || !t.monitor)));
    }
    readonly property real each: windows.length ? Math.min(Theme.taskButtonMax, (width + 3) / windows.length - 3) : 0

    function addr(t) { return t.address.startsWith("0x") ? t.address : "0x" + t.address; }
    function isMin(t) { return t.workspace?.name === minimized; }
    function focusWin(t) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`); }
    function minimize(t) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${minimized}", window = "address:${addr(t)}", follow = false })`);
    }
    function restore(t) {
        const ws = monitor?.activeWorkspace?.id ?? 1;
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${addr(t)}", follow = false })`);
        focusLater.t = t;
        focusLater.restart();
    }
    Timer { id: focusLater; property var t; interval: 60; onTriggered: root.focusWin(t) }
    // Focus the window first, then run a dispatcher on "the active window"
    function onWindow(t, lua) {
        focusWin(t);
        actLater.lua = lua;
        actLater.restart();
    }
    Timer { id: actLater; property string lua; interval: 60; onTriggered: Hyprland.dispatch(lua) }

    function appIcon(t) {
        const id = t.wayland?.appId ?? t.lastIpcObject?.class ?? "";
        const e = id ? DesktopEntries.heuristicLookup(id) : null;
        return e?.icon || "application-x-executable";
    }

    function windowMenu(t, x, y) {
        const min = isMin(t);
        const count = Math.max(5, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id));
        const moves = [];
        for (let i = 1; i <= count; i++)
            moves.push({ text: `Workspace ${i}`, radio: t.workspace?.id === i,
                         run: () => Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${i}, window = "address:${addr(t)}", follow = false })`) });
        Menus.show(screenName, "tray", [
            { text: "Restore", icon: "", enabled: min, run: () => restore(t) },
            { text: "Minimize", enabled: !min, run: () => minimize(t) },
            { text: "Maximize", enabled: !min, run: () => onWindow(t, "hl.dsp.window.fullscreen()") },
            { text: "Float / Tile", enabled: !min, run: () => onWindow(t, `hl.dsp.window.float({ action = "toggle" })`) },
            { text: "Move to", sub: moves },
            { sep: true },
            { text: "Close", bold: true, hint: "Super+C", run: () => onWindow(t, "hl.dsp.window.close()") },
        ], x, y, { up: true });
    }

    Row {
        spacing: 3
        Repeater {
            model: root.windows
            Btn {
                id: b
                required property var modelData
                readonly property bool min: root.isMin(modelData)
                width: root.each
                height: Theme.taskButton
                implicitWidth: root.each
                align: Qt.AlignLeft
                padding: 5
                checked: modelData.activated && !min
                bold: checked
                activeFocusOnTab: false
                icon: root.appIcon(modelData)
                iconSize: Theme.icon
                text: modelData.title || (modelData.wayland?.appId ?? "")
                opacity: min ? 0.75 : 1
                onClicked: {
                    if (min) root.restore(modelData);
                    else if (modelData.activated) root.minimize(modelData);
                    else root.focusWin(modelData);
                }
                onRightClicked: {
                    const p = b.mapToItem(null, 0, 0);
                    root.windowMenu(modelData, p.x, root.screenHeight - Theme.taskbarHeight);
                }
                Tip { target: b; hovered: b.hovered; text: b.text }
            }
        }
    }
}
