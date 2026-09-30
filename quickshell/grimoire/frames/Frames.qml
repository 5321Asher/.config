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
// windows and takes no input. Fullscreen windows get none.
//
// Keeping up: Hyprland announces nothing while a window is dragged, so this asks it for the windows
// directly (Hyprland.refreshToplevels): every frame while the window is moving, ten times a
// second while it's still. Continuous motion (a drag, a resize) is followed exactly; a single jump
// (moved by a key, re-tiled) glides there on Hyprland's own curve for Grimoire's windows (look.lua:
// windowsMove, speed 4 = 400 ms, bezier "arcane"), so the corners travel with the window.
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

    // ---------------------------------------------------------------- asking Hyprland
    // the focused window, as Hyprland last said (Hyprland.refreshToplevels asks its socket for
    // j/clients; a Socket of our own would work too, but Hyprland hangs up after every answer and
    // Quickshell logs a warning each time)
    readonly property var win: Hyprland.activeToplevel?.lastIpcObject ?? null
    readonly property var focused: {
        const o = shown;
        if (!o || !o.at || !o.size || o.hidden || o.mapped === false || (o.fullscreen ?? 0) > 0) return null;
        const ws = o.workspace?.name ?? "";
        const here = special !== "" ? ws === special : o.workspace?.id === wsId;
        return here ? o : null;
    }
    property var shown: null            // `win`, taken once we've decided how to move to it
    property real lastMove: 0           // when the window last changed place or size (ms)
    property bool gliding: true          // the next change glides (a jump), or snaps (a drag)
    onWinChanged: {
        const o = win, p = shown;
        if (o && p && o.address === p.address && o.at && p.at
            && (p.at[0] !== o.at[0] || p.at[1] !== o.at[1] || p.size[0] !== o.size[0] || p.size[1] !== o.size[1])) {
            const now = Date.now();
            // part of a run of changes (dragging, resizing): follow exactly; on its own: glide
            gliding = now - lastMove > 160 && !(o.floating && now - lastMove < 1000);
            lastMove = now;
            stillFor.restart();
        }
        shown = o;
    }
    function ask() { Hyprland.refreshToplevels(); }
    // moving: something changed in the last 1.2 s
    Timer { id: stillFor; interval: 1200 }
    readonly property bool moving: stillFor.running || fastFor.running
    FrameAnimation { running: root.visible && root.moving; onTriggered: root.ask() }
    Timer { running: root.visible && !root.moving; repeat: true; interval: 100; onTriggered: root.ask() }
    // after any window event, watch closely for a while (a move is probably under way)
    Timer { id: fastFor; interval: 1200 }
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspace",
                 "workspacev2", "activespecial", "activespecialv2", "focusedmon", "moveworkspace", "resizewindow"].includes(e.name)) {
                fastFor.restart();
                root.ask();
            }
            if (e.name === "activewindowv2") { draw.restart(); fastFor.restart(); root.ask(); }
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
        // Hyprland's windowsMove: 400 ms on the "arcane" bezier (0.22, 1, 0.36, 1)
        readonly property bool glide: root.grow >= 1 && root.gliding
        Behavior on x { enabled: box.glide; NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
        Behavior on y { enabled: box.glide; NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
        Behavior on width { enabled: box.glide; NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
        Behavior on height { enabled: box.glide; NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }

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
