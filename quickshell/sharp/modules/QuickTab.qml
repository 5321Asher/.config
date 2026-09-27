import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Toggles, brightness, capture, dictation and power
Flickable {
    id: root

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btConnected: bt?.devices.values.filter(d => d.connected) ?? []

    // Asks the panel to close (before screenshots etc.)
    signal closeRequested

    // Stay awake: hold a systemd idle inhibitor (hypridle respects it) while on
    Process {
        id: awake
        command: ["systemd-inhibit", "--what=idle", "--who=Sharp", "--why=Stay awake (control panel)", "sleep", "infinity"]
    }

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function activate() {
        Net.refresh();
        if (!Brightness.scanned)
            Brightness.scan();
    }

    Component.onCompleted: activate()
    onVisibleChanged: if (visible) activate()

    ColumnLayout {
        id: content

        width: root.width
        spacing: 10

        // Toggles
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Toggle {
                icon: root.glyph(Net.wifiEnabled ? 0xF05A9 : 0xF05AA)
                title: "Wi-Fi"
                status: !Net.wifiEnabled ? "Off" : Net.ssid || "Not connected"
                active: Net.wifiEnabled
                onClicked: Net.toggleWifi()
            }

            Toggle {
                icon: root.glyph(root.bt?.enabled ? 0xF00AF : 0xF00B2)
                title: "Bluetooth"
                status: !root.bt ? "No adapter"
                    : !root.bt.enabled ? "Off"
                    : root.btConnected.length === 1 ? root.btConnected[0].name
                    : root.btConnected.length > 1 ? root.btConnected.length + " devices"
                    : "On"
                active: root.bt?.enabled ?? false
                enabled: !!root.bt
                onClicked: root.bt.enabled = !root.bt.enabled
            }

            Toggle {
                icon: root.glyph(0xF0582)
                title: "Tailscale"
                status: !Net.tsAvailable ? "Unavailable"
                    : Net.tsRunning ? Net.tsPeersOnline + " peers online" : "Off"
                active: Net.tsRunning
                enabled: Net.tsAvailable
                onClicked: Net.toggleTailscale()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Toggle {
                icon: root.glyph(Notifs.dnd ? 0xF009B : 0xF009A)
                title: "DND"
                status: Notifs.dnd ? "Only critical pop up" : "Notifications on"
                active: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Toggle {
                icon: root.glyph(0xF0176)
                title: "Stay awake"
                status: awake.running ? "No dim, lock or sleep" : "Idle timers normal"
                active: awake.running
                onClicked: awake.running = !awake.running
            }

            Toggle {
                icon: root.glyph(0xF0335)
                title: "Lights follow"
                status: !Rgb.scanned ? "Checking…" : !Rgb.available ? "OpenRGB not found"
                    : Rgb.followWallpaper ? "Theme accent" : "Manual"
                active: Rgb.followWallpaper
                enabled: Rgb.available || !Rgb.scanned
                onClicked: Rgb.setFollowWallpaper(!Rgb.followWallpaper)
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Net.tsError !== ""
            text: Net.tsError
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.warn
        }

        // Brightness
        Card {
            title: "Brightness"

            Text {
                visible: Brightness.scanning && Brightness.displays.length === 0
                text: "Looking for displays…"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }

            Text {
                Layout.fillWidth: true
                visible: Brightness.scanned && !Brightness.available
                text: "Install ddcutil to control monitor brightness"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }

            Text {
                Layout.fillWidth: true
                visible: Brightness.scanned && Brightness.available && Brightness.displays.length === 0
                text: "No DDC/CI displays found (is the i2c-dev module loaded?)"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }

            Repeater {
                model: Brightness.displays

                RowLayout {
                    id: disp

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.glyph(0xF00DF)
                        font.family: Theme.font
                        font.pixelSize: 16
                        color: Theme.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: disp.modelData.name
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.fg
                            }

                            Text {
                                text: Math.round(disp.modelData.value * 100) + "%"
                                font.family: Theme.font
                                font.pixelSize: 11
                                color: Theme.dim
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            value: disp.modelData.value
                            onMoved: v => Brightness.set(disp.index, v)
                        }
                    }
                }
            }
        }

        // Capture
        Card {
            title: "Capture"
            trailing: Capture.recording ? "● REC " + Capture.elapsedText : ""
            trailingColor: Theme.danger

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    icon: root.glyph(0xF0E51)
                    label: "Region"
                    onClicked: {
                        root.closeRequested();
                        Capture.screenshot("region");
                    }
                }

                ActionButton {
                    icon: root.glyph(0xF0100)
                    label: "Screen"
                    onClicked: {
                        root.closeRequested();
                        Capture.screenshot("screen");
                    }
                }

                ActionButton {
                    icon: root.glyph(0xF113A)
                    label: "Text"
                    onClicked: {
                        root.closeRequested();
                        Capture.ocr();
                    }
                }

                ActionButton {
                    icon: root.glyph(Capture.recording ? 0xF04DB : 0xF044B)
                    label: Capture.recording ? "Stop" : "Record"
                    danger: Capture.recording
                    enabled: Capture.recording || Capture.recorder !== ""
                    onClicked: {
                        if (!Capture.recording)
                            root.closeRequested();
                        Capture.toggleRecording();
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Capture.recorder === ""
                text: "Install gpu-screen-recorder or wf-recorder to record"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        // Dictation (voxtype)
        Card {
            visible: Voxtype.available
            title: "Dictation"
            trailing: Voxtype.recording ? "● " + Voxtype.elapsedText
                    : Voxtype.transcribing ? "TRANSCRIBING"
                    : Voxtype.running ? Voxtype.model : "OFF"
            trailingColor: Voxtype.recording ? Theme.danger : Voxtype.running ? Theme.dim : Theme.warn

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    icon: root.glyph(Voxtype.recording ? 0xF04DB : 0xF036C)
                    label: !Voxtype.running ? "Start service" : Voxtype.recording ? "Finish" : "Dictate"
                    danger: Voxtype.recording
                    enabled: !Voxtype.transcribing
                    onClicked: {
                        // Close first so the text lands in the window you were typing in
                        if (Voxtype.running && !Voxtype.recording)
                            root.closeRequested();
                        Voxtype.toggle();
                    }
                }

                ActionButton {
                    icon: root.glyph(0xF0156)
                    label: "Cancel"
                    enabled: Voxtype.busy
                    onClicked: Voxtype.cancel()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "SUPER+Z to start and finish · SUPER+SHIFT+Z to cancel"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        // Power
        Card {
            title: "Power"

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PowerButton {
                    visible: Capture.hasHyprlock
                    icon: root.glyph(0xF033E)
                    label: "Lock"
                    confirm: false
                    command: ["hyprlock"]
                }
                PowerButton {
                    icon: root.glyph(0xF0343)
                    label: "Log out"
                    command: ["hyprctl", "dispatch", "hl.dsp.exit()"]
                }
                PowerButton {
                    icon: root.glyph(0xF04B2)
                    label: "Sleep"
                    confirm: false
                    command: ["systemctl", "suspend"]
                }
                PowerButton {
                    icon: root.glyph(0xF0709)
                    label: "Restart"
                    command: ["systemctl", "reboot"]
                }
                PowerButton {
                    icon: root.glyph(0xF0425)
                    label: "Shut down"
                    command: ["systemctl", "poweroff"]
                }
            }
        }
    }

    // --- Components ---

    component Card: Rectangle {
        id: card

        property string title
        property string trailing
        property color trailingColor: Theme.accent
        default property alias items: body.data

        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        radius: 0
        color: Theme.bgDark
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: col

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: card.title
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                    color: Theme.dim
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: card.trailing
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    color: card.trailingColor
                }
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 12
            }
        }
    }

    component Toggle: Rectangle {
        id: tg

        property string icon
        property string title
        property string status
        property bool active
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 96
        radius: 0
        opacity: enabled ? 1 : 0.5
        color: active ? Theme.surface : tgMouse.containsMouse ? Theme.hover : Theme.bgDark
        border.width: 1
        border.color: active ? Theme.accent : Theme.border
        scale: tgMouse.pressed ? 0.96 : 1

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 100 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 2

            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: 0
                color: tg.active ? Theme.bgDark : Theme.hover

                Text {
                    anchors.centerIn: parent
                    text: tg.icon
                    font.family: Theme.font
                    font.pixelSize: 17
                    color: tg.active ? Theme.accent : Theme.fg
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: tg.title
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
                color: tg.active ? Theme.accent : Theme.fg
            }

            Text {
                Layout.fillWidth: true
                text: tg.status
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 10
                color: Theme.dim
            }
        }

        MouseArea {
            id: tgMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tg.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: ab

        property string icon
        property string label
        property bool danger: false
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 64
        radius: 0
        opacity: enabled ? 1 : 0.4
        color: danger ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.18)
             : abMouse.containsMouse ? Theme.border : Theme.hover
        border.width: danger ? 1 : 0
        border.color: Theme.danger
        scale: abMouse.pressed ? 0.96 : 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 100 } }

        Column {
            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ab.icon
                font.family: Theme.font
                font.pixelSize: 20
                color: ab.danger ? Theme.danger : Theme.fg
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ab.label
                font.family: Theme.font
                font.pixelSize: 11
                color: ab.danger ? Theme.danger : Theme.dim
            }
        }

        MouseArea {
            id: abMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }

    // Destructive actions need a second click within 3 seconds
    component PowerButton: Rectangle {
        id: pb

        property string icon
        property string label
        property var command
        property bool confirm: true
        property bool armed: false

        Layout.fillWidth: true
        implicitHeight: 64
        radius: 0
        color: armed ? Theme.danger : pbMouse.containsMouse ? Theme.border : Theme.hover
        scale: pbMouse.pressed ? 0.96 : 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 100 } }

        Timer {
            id: disarm
            interval: 3000
            onTriggered: pb.armed = false
        }

        Column {
            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pb.icon
                font.family: Theme.font
                font.pixelSize: 18
                color: pb.armed ? Theme.bg : Theme.fg
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pb.armed ? "Sure?" : pb.label
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: pb.armed
                color: pb.armed ? Theme.bg : Theme.dim
            }
        }

        MouseArea {
            id: pbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (pb.confirm && !pb.armed) {
                    pb.armed = true;
                    disarm.restart();
                    return;
                }
                pb.armed = false;
                root.closeRequested();
                Quickshell.execDetached(pb.command);
            }
        }
    }
}
