import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The power screen (the rail's power glyph, Power in the index): the screen goes almost black, a
// column of Doto words on the left (the selected one big with the red dot, the rest dim; ↑↓ grow and
// shrink them), and on the right a ring of 60 dots: the uptime (a six-hour shift), the windows open.
// Enter confirms, Esc cancels. State: PowerState.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    readonly property real s: Theme.scaleFor(screen)

    property real t: PowerState.open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0

    property int sel: 2
    readonly property var items: [
        ["LOCK", ["loginctl", "lock-session"]],
        ["SLEEP", ["systemctl", "suspend"]],
        ["SHUT DOWN", ["systemctl", "poweroff"]],
        ["REBOOT", ["systemctl", "reboot"]],
        ["LOG OUT", ["hyprctl", "dispatch", "hl.dsp.exit()"]]
    ]

    property real uptime: 0
    FileView { id: up; path: "/proc/uptime"; onLoaded: root.uptime = parseFloat(text()) || 0 }
    Connections {
        target: PowerState
        function onOpenChanged() {
            if (!PowerState.open) return;
            root.sel = 2;
            up.reload();
            keys.forceActiveFocus();
        }
    }
    function accept() {
        PowerState.open = false;
        later.cmd = items[sel][1];
        later.restart();
    }
    Timer { id: later; property var cmd; interval: Theme.t + 60; onTriggered: Quickshell.execDetached(cmd) }

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PowerState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-power"

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.bg, 0.96)
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: PowerState.open = false }
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Up || e.key === Qt.Key_K) root.sel = (root.sel + 4) % 5;
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J || e.key === Qt.Key_Tab) root.sel = (root.sel + 1) % 5;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.accept();
            else if (e.key === Qt.Key_Escape) PowerState.open = false;
            else return;
            e.accepted = true;
        }
    }

    Stage {
        id: stage
        s: root.s
        opacity: root.t
        readonly property bool wide: width >= 1500

        Column {
            x: stage.wide ? 240 : 80
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: stage.wide ? 0 : 200
            spacing: 26
            Repeater {
                model: root.items
                Row {
                    id: it
                    required property var modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    spacing: 30
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: 15
                        color: Theme.red
                        scale: it.on ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                    }
                    Num {
                        text: it.modelData[0]
                        font.pixelSize: it.on ? (stage.wide ? 168 : 110) : 66
                        color: it.on ? Theme.fg : Theme.mute
                        Behavior on font.pixelSize { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                        // only real pointer motion selects: a word growing under a still pointer mustn't
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: root.sel = it.index
                            onClicked: { root.sel = it.index; root.accept(); }
                        }
                    }
                }
            }
        }

        Item {
            x: stage.wide ? stage.width - 200 - 460 : (stage.width - 380) / 2
            y: stage.wide ? (stage.height - height) / 2 : 120
            width: stage.wide ? 460 : 380
            height: width
            Ring { anchors.fill: parent; n: 60; dot: 10; f: root.uptime / (6 * 3600) }
            Column {
                anchors.centerIn: parent
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: "uptime" }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: lead + 10
                    bottomPadding: lead + 10
                    text: `${Math.floor(root.uptime / 3600)}:${String(Math.floor(root.uptime / 60) % 60).padStart(2, "0")}`
                    font.pixelSize: 110
                }
                Lb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int n: Hyprland.toplevels.values.length
                    text: `${n} window${n === 1 ? "" : "s"} open`
                }
            }
        }

        Row {
            x: stage.wide ? 240 : 80
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: "↑↓ select" }
            Lb { text: "↵ confirm" }
            Lb { text: "esc cancel" }
        }
    }
}
