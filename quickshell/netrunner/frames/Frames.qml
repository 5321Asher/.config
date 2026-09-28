import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

// The window frames' accents, after the references. Hyprland cuts the corners and draws the hairline
// itself (look.lua: rounding with rounding_power 1 makes the corners straight diagonals; the border
// is red on the focused window, grey on the rest). This layer adds what Hyprland can't: a short red
// bar along the focused window's top edge and a tick down its right side (a grey stub on the others).
// It sits over the windows, takes no input, and follows them on every window event (and a slow
// poll, for resizes Hyprland doesn't announce). Fullscreen windows get none.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "netrunner-frames"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    readonly property var mon: monitor?.lastIpcObject ?? {}
    readonly property string special: mon.specialWorkspace?.name ?? ""
    readonly property int wsId: monitor?.activeWorkspace?.id ?? -1

    property int tick: 0
    readonly property var windows: {
        tick;
        return Hyprland.toplevels.values.filter(t => {
            const o = t.lastIpcObject ?? {};
            if (!o.at || !o.size || o.hidden || o.mapped === false) return false;
            if ((o.fullscreen ?? 0) > 0) return false;
            const ws = t.workspace?.name ?? "";
            return special !== "" ? ws === special : t.workspace?.id === wsId;
        });
    }

    // Hyprland only updates lastIpcObject when asked
    function refreshSoon() { refresher.restart(); }
    Timer { id: refresher; interval: 40; onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshMonitors(); root.tick++; } }
    Timer { running: true; repeat: true; interval: 1500; onTriggered: root.refreshSoon() }
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspace",
                 "workspacev2", "activespecial", "activespecialv2", "activewindowv2", "focusedmon", "moveworkspace",
                 "resizewindow", "pin", "togglegroup", "moveintogroup", "moveoutofgroup"].includes(e.name))
                root.refreshSoon();
        }
    }

    Repeater {
        model: root.windows
        Item {
            id: f
            required property var modelData
            readonly property var o: modelData.lastIpcObject ?? {}
            readonly property bool active: modelData.activated
            readonly property real c: Theme.chamfer
            x: (o.at?.[0] ?? 0) - (root.mon.x ?? 0)
            y: (o.at?.[1] ?? 0) - (root.mon.y ?? 0)
            width: o.size?.[0] ?? 0
            height: o.size?.[1] ?? 0
            z: o.floating ? 2 : 1

            // the focused window's red bar, top left, and a tick at the far corner
            // (the outline and the cut corners are Hyprland's own: look.lua, rounding_power 1)
            Rectangle { visible: f.active; x: f.c; y: -1; width: Math.min(90, f.width / 4); height: 3; color: Theme.red }
            Rectangle { visible: f.active; x: f.width - 2; y: f.height - f.c - 20; width: 3; height: 20; color: Theme.red }
            Rectangle { visible: !f.active; x: f.c; y: -1; width: Math.min(40, f.width / 8); height: 2; color: Theme.alpha(Theme.dim, 0.6) }
        }
    }
}
