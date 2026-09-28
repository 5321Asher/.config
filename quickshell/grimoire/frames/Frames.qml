import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// Gilt flourishes on the focused window's four corners. Hyprland draws the gold-leaf rule round
// every window (look.lua and the theme's activeBorder colours); this layer adds the ornament it
// can't: at each corner an L of gold that runs a little way along both edges (in the gap) and ends
// in scrolled curls. They draw themselves in whenever the focus moves. The layer sits over the
// windows, takes no input, and follows the focused window on every window event (and a slow poll,
// for resizes Hyprland doesn't announce). Fullscreen windows get none.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "grimoire-frames"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    readonly property var mon: monitor?.lastIpcObject ?? {}
    readonly property string special: mon.specialWorkspace?.name ?? ""
    readonly property int wsId: monitor?.activeWorkspace?.id ?? -1

    property int tick: 0
    readonly property var focused: {
        tick;
        const t = Hyprland.activeToplevel;
        if (!t) return null;
        const o = t.lastIpcObject ?? {};
        if (!o.at || !o.size || o.hidden || o.mapped === false || (o.fullscreen ?? 0) > 0) return null;
        const ws = t.workspace?.name ?? "";
        const here = special !== "" ? ws === special : t.workspace?.id === wsId;
        return here ? o : null;
    }

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
            if (e.name === "activewindowv2") draw.restart();
        }
    }

    // the flourishes grow in when the focus changes
    property real grow: 1
    NumberAnimation { id: draw; target: root; property: "grow"; from: 0; to: 1; duration: Theme.stately; easing.type: Easing.OutCubic }

    Item {
        id: box
        visible: root.focused !== null
        readonly property var o: root.focused ?? {}
        x: (o.at?.[0] ?? 0) - (root.mon.x ?? 0)
        y: (o.at?.[1] ?? 0) - (root.mon.y ?? 0)
        width: o.size?.[0] ?? 0
        height: o.size?.[1] ?? 0
        Behavior on x { enabled: root.grow >= 1; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: root.grow >= 1; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: root.grow >= 1; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: root.grow >= 1; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        readonly property real off: 6         // how far out from the window's edge the L runs
        readonly property real size: Math.min(46, Math.min(width, height) / 3)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 0.25
            shadowOpacity: 0.7
            shadowHorizontalOffset: 1
            shadowVerticalOffset: 1
            blurMax: 6
        }

        Repeater {
            model: ["tl", "tr", "bl", "br"]
            Flourish {
                required property string modelData
                corner: modelData
                size: box.size
                leaf: false
                stroke: 1.8
                grow: root.grow
                color: Theme.goldBright
                shade: Theme.goldDeep
                x: modelData.endsWith("l") ? -box.off : box.width - box.size + box.off
                y: modelData.startsWith("t") ? -box.off : box.height - box.size + box.off
            }
        }
    }
}
