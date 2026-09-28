import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../services"

// The deck: Netrunner's dashboard, on the special workspace "deck" (the bar's DECK chip, the hub,
// or `hyprctl dispatch 'hl.dsp.workspace.toggle_special("deck")'`). Windows opened there tile in
// the top-left (look.lua gives special:deck wide right and bottom gaps); these panels fill the
// rest: SYS.DIAG down the right, SIGNAL under it, QUEUE and VULN WATCH along the bottom.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property bool shown: (monitor?.lastIpcObject?.specialWorkspace?.name ?? "") === "special:deck"

    visible: shown || fade > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "netrunner-deck"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // input only on the panels (the windows between them stay usable)
    mask: Region {
        Region { item: diag }
        Region { item: signal }
        Region { item: queue }
        Region { item: vuln }
    }

    property real fade: shown ? 1 : 0
    Behavior on fade { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name.startsWith("activespecial")) Hyprland.refreshMonitors(); }
    }
    onShownChanged: if (shown) { Status.refresh(); Net.refresh(); }

    readonly property int m: Theme.gap
    readonly property int rightW: Theme.deckRight
    readonly property int bottomH: Theme.deckBottom

    Item {
        anchors.fill: parent
        opacity: root.fade

        SysDiag {
            id: diag
            x: root.width - root.rightW - root.m
            y: root.m
            width: root.rightW
            height: root.height - root.bottomH - root.m * 3
        }
        SignalPanel {
            id: signal
            x: diag.x
            y: root.height - root.bottomH - root.m
            width: root.rightW
            height: root.bottomH
        }
        QueuePanel {
            id: queue
            x: root.m
            y: signal.y
            width: (diag.x - root.m * 3) * 0.56
            height: root.bottomH
        }
        VulnWatch {
            id: vuln
            x: queue.x + queue.width + root.m
            y: signal.y
            width: diag.x - x - root.m
            height: root.bottomH
        }
    }
}
