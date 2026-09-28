import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../rig"
import "../launcher"
import "../utilities"

// The bar, along the top of every screen, after the references: the red tag (the hub), the
// workspaces, the ticker, then the readouts: CPU, MEM, the net sparkline with ▲ up ▼ down,
// Bluetooth, power, recording / dictation / focus timer when running, the tray, IDLE // HOLD
// (stay awake), messages, and the clock with its seconds in red. Everything opens its rig page.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "netrunner-bar"
    exclusiveZone: Theme.barHeight

    Component.onCompleted: SysStats.active = true

    // testing: render the bar to a PNG (works while the screen is locked)
    //   qs ipc -c netrunner call debug grab bar /path.png
    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "bar" && root.modelData === Quickshell.screens[0]) body.grabToImage(r => r.saveToFile(path)); }
    }

    readonly property var s: SysStats.data
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btConnected: (bt?.devices?.values ?? []).filter(d => d.connected)
    readonly property var battery: UPower.displayDevice

    // everything drawn, in one item (so it can be rendered to a file for testing)
    Item {
        id: body
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bg, 0.86)
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.alpha(Theme.line, 0.9) }

        // ---------------------------------------------------------------- left: tag, workspaces, ticker
        Tag {
            id: tag
            x: 0
            height: parent.height
            width: Theme.tagWidth
            slant: 16
            padding: 14
            pixelSize: 18
            family: Theme.display
            text: (Quickshell.env("USER") ?? "net").slice(0, 2).toUpperCase() + "//" + Qt.formatDate(clock.date, "dd")
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: HubState.toggle() }
        }
        Rectangle { x: tag.width - 16; anchors.bottom: parent.bottom; width: ws.x + ws.width - x; height: 2; color: Theme.red; visible: false }

        Workspaces {
            id: ws
            x: tag.width + 4
            monitor: root.monitor
            screenIndex: Quickshell.screens.indexOf(root.modelData)
        }
        Sep { id: sep1; x: ws.x + ws.width + 8 }
        Ticker {
            x: sep1.x + 12
            width: Math.max(0, readouts.x - x - 16)
            height: parent.height
            onClicked: RigState.toggleTo("telemetry")
        }

        // ---------------------------------------------------------------- right: readouts
        Row {
            id: readouts
            anchors.right: parent.right
            anchors.rightMargin: 14
            height: parent.height
            spacing: 16

            Jp { anchors.verticalCenter: parent.verticalCenter; text: "レイス" }

            Readout {
                onClicked: RigState.toggleTo("telemetry")
                Label { text: "CPU"; anchors.verticalCenter: parent.verticalCenter }
                Blocks { anchors.verticalCenter: parent.verticalCenter; value: (root.s?.cpu?.usage ?? 0) / 100
                         color: (root.s?.cpu?.usage ?? 0) > 85 ? Theme.red : Theme.cyan }
                Label { width: 34; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.s?.cpu?.usage ?? 0) + "%"; strong: true }
            }
            Sep {}
            Readout {
                onClicked: RigState.toggleTo("telemetry")
                Label { text: "MEM"; anchors.verticalCenter: parent.verticalCenter }
                Blocks { anchors.verticalCenter: parent.verticalCenter
                         value: root.s ? root.s.mem.used / root.s.mem.total : 0 }
                Label { anchors.verticalCenter: parent.verticalCenter; strong: true
                        text: root.s ? (root.s.mem.used / 1073741824).toFixed(1) + "/" + (root.s.mem.total / 1073741824).toFixed(1) + "G" : "" }
            }
            Sep {}
            Readout {
                onClicked: RigState.toggleTo("comms")
                // signal bars
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                    spacing: 1
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 3; height: 4 + index * 3
                            color: Status.ping < 0 ? Theme.alpha(Theme.dim, 0.5) : index < (Status.ping < 30 ? 4 : Status.ping < 80 ? 3 : 2) ? Theme.cyan : Theme.alpha(Theme.dim, 0.5)
                        }
                    }
                }
                Spark {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50; height: 16
                    values: SysStats.rxHistory
                    base: Theme.alpha(Theme.cyan, 0.5)
                }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "▲" + root.rate(root.s?.net?.tx ?? 0); color: Theme.red; strong: true }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "▼" + root.rate(root.s?.net?.rx ?? 0); color: Theme.cyan; strong: true }
            }
            Readout {
                onClicked: RigState.toggleTo("comms")
                Text { anchors.verticalCenter: parent.verticalCenter; text: "\u{f00af}"; color: root.bt?.enabled ? Theme.fg : Theme.dim
                       font.family: Theme.mono; font.pixelSize: Theme.data }
                Label { anchors.verticalCenter: parent.verticalCenter; strong: root.btConnected.length > 0
                        text: !root.bt?.enabled ? "OFF" : root.btConnected.length ? root.btConnected[0].name : "NONE"
                        color: root.btConnected.length ? Theme.cyan : Theme.dim }
            }
            Readout {
                onClicked: RigState.toggleTo("hangar")
                Label { anchors.verticalCenter: parent.verticalCenter; text: "PWR" }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    strong: true
                    readonly property bool onBattery: root.battery?.isLaptopBattery && root.battery.state === UPowerDeviceState.Discharging
                    text: root.battery?.isLaptopBattery ? Math.round(root.battery.percentage * (root.battery.percentage > 1 ? 1 : 100)) + "%" + (onBattery ? "" : " AC") : "AC"
                    color: onBattery && root.battery.percentage < 0.2 ? Theme.red : Theme.fg
                }
            }

            // running things
            Readout {
                visible: Capture.recording
                onClicked: Capture.toggleRecording()
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; color: Theme.red
                    SequentialAnimation on opacity { running: Capture.recording; loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "REC " + Capture.elapsedText; color: Theme.red; strong: true }
            }
            Readout {
                visible: Voxtype.busy
                onClicked: Voxtype.toggle()
                Label { anchors.verticalCenter: parent.verticalCenter; text: Voxtype.recording ? "VOX " + Voxtype.elapsedText : "VOX // DECODE"; color: Theme.cyan; strong: true }
            }
            Readout {
                visible: FocusTimer.active
                onClicked: RigState.toggleTo("chronometer")
                Label { anchors.verticalCenter: parent.verticalCenter; text: FocusTimer.phaseLabel + " " + FocusTimer.remainingText
                        color: FocusTimer.running ? Theme.yellow : Theme.dim; strong: true }
            }

            Tray { anchors.verticalCenter: parent.verticalCenter; bar: root }

            // IDLE // HOLD: stay awake
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: idleLabel.implicitWidth + 20
                height: 26
                Rectangle {
                    anchors.fill: parent
                    color: StayAwake.on ? Theme.alpha(Theme.red, 0.18) : "transparent"
                    border.width: 1
                    border.color: StayAwake.on ? Theme.red : Theme.line
                }
                Label { id: idleLabel; anchors.centerIn: parent; text: StayAwake.on ? "IDLE // HOLD" : "IDLE // AUTO"; color: StayAwake.on ? Theme.red : Theme.dim }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: StayAwake.on = !StayAwake.on }
            }

            // messages
            Readout {
                onClicked: RigState.toggleTo("log")
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.dnd ? "\u{f009b}" : "\u{f0369}"
                    color: Notifs.unread > 0 ? Theme.red : Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: Theme.data + 3
                }
                Label { visible: Notifs.unread > 0; anchors.verticalCenter: parent.verticalCenter; text: Notifs.unread; color: Theme.red; strong: true }
            }

            // the clock
            Readout {
                onClicked: RigState.toggleTo("almanac")
                spacing: 3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    text: Qt.formatTime(clock.date, "ss")
                    color: Theme.red
                    font.family: Theme.display
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                Label { anchors.verticalCenter: parent.verticalCenter; leftPadding: 8
                        text: Qt.formatDate(clock.date, "MM.dd.yy ddd"); strong: true; color: Theme.fg }
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    function rate(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + "M" : b >= 1024 ? Math.round(b / 1024) + "K" : "0K";
    }

    // a readout: a row of pieces, clickable
    component Readout: Item {
        id: ro
        default property alias content: roRow.data
        property alias spacing: roRow.spacing
        signal clicked()
        width: roRow.width
        height: parent ? parent.height : Theme.barHeight
        Row { id: roRow; spacing: 6; height: parent.height }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ro.clicked() }
    }
    component Sep: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1; height: 18
        color: Theme.alpha(Theme.line, 1)
    }
}
