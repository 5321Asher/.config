import QtQuick
import Quickshell
import Quickshell.Hyprland

Row {
    id: root

    property ShellScreen screen
    property int count: Config.workspaceCount

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    // Name of the special workspace (scratchpad) open on this monitor, "" when none
    property string special: ""
    readonly property bool inSpecial: special !== ""

    spacing: 6

    function syncSpecial() {
        const name = root.monitor?.lastIpcObject?.specialWorkspace?.name ?? "";
        root.special = name.replace(/^special:/, "");
    }

    onMonitorChanged: syncSpecial()
    Component.onCompleted: Hyprland.refreshMonitors()

    Connections {
        target: root.monitor
        function onLastIpcObjectChanged() { root.syncSpecial(); }
    }

    Connections {
        target: Hyprland
        // activespecial>>special:NAME,MONITOR (name empty when the scratchpad closes)
        function onRawEvent(event) {
            if (event.name !== "activespecial") return;
            const i = event.data.lastIndexOf(",");
            if (event.data.slice(i + 1) !== root.monitor?.name) return;
            root.special = event.data.slice(0, i).replace(/^special:/, "");
        }
    }

    Repeater {
        model: root.count

        Rectangle {
            id: pill

            required property int index
            readonly property int wsId: index + 1
            readonly property HyprlandWorkspace ws:
                Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            // Active = shown on this bar's monitor
            readonly property bool active: root.monitor?.activeWorkspace?.id === wsId
            readonly property bool occupied: (ws?.toplevels.values.length ?? 0) > 0

            anchors.verticalCenter: parent.verticalCenter
            height: 22
            width: active ? 40 : 22
            radius: 0
            color: active ? Theme.surface
                 : mouse.containsMouse ? Theme.hover
                 : occupied ? Theme.surface
                 : "transparent"
            border.width: 1
            border.color: active ? Theme.accent : occupied ? Theme.accentMuted : Theme.border

            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: pill.wsId
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: pill.active
                color: pill.active ? Theme.accent : pill.occupied ? Theme.fg : Theme.dim
            }

            // Scratchpad is open over this workspace (on this bar's monitor)
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.3)
                border.width: 1
                border.color: Theme.green
                opacity: pill.active && root.inSpecial ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Lua-config Hyprland: dispatch takes hl.dsp expressions
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${pill.wsId} })`)
            }
        }
    }
}
