import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

// Bluetooth: power, scanning, paired devices and devices in range
Flickable {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices just show a MAC address, which isn't useful
    readonly property var available: devices.filter(d => !d.paired && !d.bonded && d.name && d.name !== d.address.replace(/:/g, "-"))

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    function deviceIcon(dev) {
        const i = dev.icon ?? "";
        if (i.includes("headset") || i.includes("headphone")) return glyph(0xF02CB);
        if (i.includes("audio") || i.includes("speaker")) return glyph(0xF04C3);
        if (i.includes("mouse")) return glyph(0xF037D);
        if (i.includes("keyboard")) return glyph(0xF030C);
        if (i.includes("gaming") || i.includes("joystick")) return glyph(0xF0296);
        if (i.includes("phone")) return glyph(0xF011C);
        if (i.includes("computer")) return glyph(0xF0322);
        return glyph(0xF00AF);
    }

    function stateText(dev) {
        if (dev.pairing) return "Pairing…";
        const s = dev.state;
        if (s === BluetoothDeviceState.Connecting) return "Connecting…";
        if (s === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (dev.connected)
            return dev.batteryAvailable ? "Connected  ·  " + Math.round(dev.battery * 100) + "%" : "Connected";
        return dev.paired ? "Paired" : "";
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Stop scanning when leaving the page
    onVisibleChanged: if (!visible && adapter?.discovering) adapter.discovering = false

    ColumnLayout {
        id: content

        width: root.width
        spacing: 10

        Card {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: root.glyph(root.adapter?.enabled ? 0xF00AF : 0xF00B2)
                    font.family: Theme.font
                    font.pixelSize: 20
                    color: root.adapter?.enabled ? Theme.accent : Theme.dim
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: "Bluetooth"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.fg
                    }

                    Text {
                        text: !root.adapter ? "No adapter found"
                            : !root.adapter.enabled ? "Off"
                            : root.adapter.discovering ? "Scanning for devices…"
                            : "Visible as “" + root.adapter.name + "”"
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.dim
                    }
                }

                IconButton {
                    visible: root.adapter?.enabled ?? false
                    icon: root.glyph(0xF0450)
                    label: root.adapter?.discovering ? "Stop" : "Scan"
                    spinning: root.adapter?.discovering ?? false
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }

                Switch {
                    enabled: !!root.adapter
                    checked: root.adapter?.enabled ?? false
                    onToggled: root.adapter.enabled = !root.adapter.enabled
                }
            }
        }

        Card {
            visible: root.adapter?.enabled ?? false
            title: "My devices"
            spacing: 4

            Text {
                visible: root.paired.length === 0
                text: "No paired devices"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }

            Repeater {
                model: root.paired

                DeviceRow {
                    id: pdev
                    required property var modelData
                    device: modelData

                    IconButton {
                        icon: root.glyph(0xF01B4)
                        tint: Theme.danger
                        onClicked: pdev.device.forget()
                    }

                    IconButton {
                        primary: !pdev.device.connected
                        label: pdev.device.connected ? "Disconnect" : "Connect"
                        enabled: pdev.device.state === BluetoothDeviceState.Connected
                              || pdev.device.state === BluetoothDeviceState.Disconnected
                        onClicked: pdev.device.connected ? pdev.device.disconnect() : pdev.device.connect()
                    }
                }
            }
        }

        Card {
            visible: root.adapter?.enabled ?? false
            title: "Available"
            trailing: root.adapter?.discovering ? "Scanning…" : ""
            trailingColor: Theme.dim
            spacing: 4

            Text {
                visible: root.available.length === 0
                text: root.adapter?.discovering ? "Looking for devices…" : "Press Scan to find devices"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }

            Repeater {
                model: root.available

                DeviceRow {
                    id: adev
                    required property var modelData
                    device: modelData

                    IconButton {
                        primary: true
                        label: adev.device.pairing ? "Pairing…" : "Pair"
                        enabled: !adev.device.pairing
                        onClicked: {
                            adev.device.trusted = true;
                            adev.device.pair();
                        }
                    }
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: dr

        property var device
        default property alias actions: actionRow.data

        Layout.fillWidth: true
        implicitHeight: 52
        radius: 0
        color: device.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
             : drMouse.containsMouse ? Theme.hover : "transparent"
        border.width: device.connected ? 1 : 0
        border.color: Theme.accent

        // Once paired, connect straight away
        Connections {
            target: dr.device
            function onPairedChanged() {
                if (dr.device.paired && !dr.device.connected)
                    dr.device.connect();
            }
        }

        MouseArea {
            id: drMouse
            anchors.fill: parent
            hoverEnabled: true
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 12

            Text {
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                text: root.deviceIcon(dr.device)
                font.family: Theme.font
                font.pixelSize: 18
                color: dr.device.connected ? Theme.accent : Theme.fg
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: dr.device.name
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.stateText(dr.device)
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.dim
                }
            }

            Row {
                id: actionRow
                spacing: 6
            }
        }
    }
}
