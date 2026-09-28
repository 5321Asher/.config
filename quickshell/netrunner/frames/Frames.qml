import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

// The window frames from the references: every window on this screen gets its top-right and
// bottom-left corners cut, a hairline round it (red for the focused window, grey otherwise) and,
// on the focused one, a short red bar along the top edge. Hyprland draws no borders here
// (look.lua); this layer sits over the windows, takes no input, and follows them on every
// window event (and a slow poll, for resizes Hyprland doesn't announce).
// Fullscreen windows get none; windows under a floating window lose theirs where it covers them.
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

            // the cut corners: the window's corner hidden under the background, then the diagonal
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: Theme.bgDark
                    strokeColor: "transparent"
                    startX: f.width - f.c - 1; startY: -1
                    PathLine { x: f.width + 1; y: -1 }
                    PathLine { x: f.width + 1; y: f.c + 1 }
                }
                ShapePath {
                    fillColor: Theme.bgDark
                    strokeColor: "transparent"
                    startX: -1; startY: f.height - f.c - 1
                    PathLine { x: f.c + 1; y: f.height + 1 }
                    PathLine { x: -1; y: f.height + 1 }
                }
                // the outline
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: f.active ? Theme.red : Theme.alpha(Theme.line, 1)
                    strokeWidth: 1
                    joinStyle: ShapePath.MiterJoin
                    startX: 0.5; startY: 0.5
                    PathLine { x: f.width - f.c - 0.5; y: 0.5 }
                    PathLine { x: f.width - 0.5; y: f.c + 0.5 }
                    PathLine { x: f.width - 0.5; y: f.height - 0.5 }
                    PathLine { x: f.c + 0.5; y: f.height - 0.5 }
                    PathLine { x: 0.5; y: f.height - f.c - 0.5 }
                    PathLine { x: 0.5; y: 0.5 }
                }
            }
            // the focused window's red bar, top left, and a tick at the far corner
            Rectangle { visible: f.active; x: 0; y: 0; width: Math.min(90, f.width / 4); height: 3; color: Theme.red }
            Rectangle { visible: f.active; x: f.width - 3; y: f.height - 18; width: 3; height: 18; color: Theme.red }
        }
    }
}
