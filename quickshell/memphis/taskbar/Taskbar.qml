import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../menus"
import "../start"

// The taskbar, along the bottom of every screen: Start, the workspace buttons, a button per window,
// and the notification area with the clock. Raised grey, with 98's light line along its top.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.taskbarHeight
    color: Theme.face
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "memphis-taskbar"
    exclusiveZone: Theme.taskbarHeight

    // top edge: light, then white
    Rectangle { width: parent.width; height: 1; color: Theme.light }
    Rectangle { y: 1; width: parent.width; height: 1; color: Theme.hilight }

    // ---------------------------------------------------------------- Start
    Btn {
        id: start
        x: 2
        y: Math.round((Theme.taskbarHeight - Theme.taskButton) / 2) + 1
        width: Theme.startWidth
        height: Theme.taskButton
        implicitWidth: Theme.startWidth
        checked: Menus.kind === "start" && Menus.screen === root.modelData.name
        dither: false
        text: "Start"
        bold: true
        padding: 4
        activeFocusOnTab: false
        Flag {}
        onClicked: StartMenu.toggle(root.modelData)
    }

    Grip { id: grip1; x: start.x + start.width + 4 }

    // ---------------------------------------------------------------- workspaces
    Pager {
        id: pager
        x: grip1.x + grip1.width + 3
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        monitor: root.monitor
    }

    Grip { id: grip2; x: pager.x + pager.width + 4 }

    // ---------------------------------------------------------------- windows
    TaskButtons {
        x: grip2.x + grip2.width + 3
        width: tray.x - x - 6
        height: Theme.taskButton
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        monitor: root.monitor
        screenName: root.modelData.name
        screenHeight: root.modelData.height
    }

    // ---------------------------------------------------------------- notification area + clock
    NotifyArea {
        id: tray
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        height: Theme.taskButton
        bar: root
    }

    // The raised grab handle between taskbar sections
    component Grip: Item {
        width: 5
        height: Theme.taskButton - 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        Sep { vertical: true; height: parent.height; x: 0 }
        Bevel { kind: "thin"; x: 2; width: 3; height: parent.height }
    }
}
