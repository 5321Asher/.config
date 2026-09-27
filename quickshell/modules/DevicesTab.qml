import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Device batteries, drives (mount / unmount / eject) and fans
Flickable {
    id: root

    // Peripheral batteries from UPower (skips the laptop battery and line power)
    readonly property var upowerDevices: UPower.devices.values.filter(d =>
        d.isPresent && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.model)
    // Bluetooth devices reporting battery that UPower doesn't already cover
    readonly property var btDevices: (Bluetooth.defaultAdapter?.devices.values ?? []).filter(d =>
        d.connected && d.batteryAvailable && !upowerDevices.some(u => u.model === d.name))
    readonly property var batteries: upowerDevices.map(d => ({
        name: d.model,
        kind: UPowerDeviceType.toString(d.type),
        percent: d.percentage > 1 ? d.percentage : d.percentage * 100,
        charging: d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge,
        full: d.state === UPowerDeviceState.FullyCharged
    })).concat(btDevices.map(d => ({
        name: d.name,
        kind: d.icon ?? "",
        percent: d.battery * 100,
        charging: false,
        full: false
    })))

    readonly property var gpu: SysStats.data?.gpu ?? null

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    function kindIcon(kind) {
        kind = kind.toLowerCase();
        if (kind.includes("mouse")) return glyph(0xF037D);
        if (kind.includes("keyboard")) return glyph(0xF030C);
        if (kind.includes("head") || kind.includes("audio")) return glyph(0xF02CB);
        if (kind.includes("gaming") || kind.includes("joystick")) return glyph(0xF0296);
        if (kind.includes("phone")) return glyph(0xF011C);
        if (kind.includes("speaker")) return glyph(0xF04C3);
        return glyph(0xF00AF);
    }

    function batteryColor(b) {
        return b.charging || b.full ? Theme.green : b.percent <= 15 ? Theme.danger : b.percent <= 30 ? Theme.warn : Theme.accent;
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Only poll drives/fans while this tab is showing
    Binding {
        target: Devices
        property: "active"
        value: root.visible
    }

    ColumnLayout {
        id: content

        width: root.width
        spacing: 10

        // Batteries
        Card {
            title: "Batteries"
            spacing: 10

            Text {
                visible: root.batteries.length === 0
                text: "No devices reporting battery"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }

            Repeater {
                model: root.batteries

                RowLayout {
                    id: bat

                    required property var modelData
                    readonly property color tint: root.batteryColor(modelData)

                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 0
                        color: Theme.hover

                        Text {
                            anchors.centerIn: parent
                            text: root.kindIcon(bat.modelData.kind)
                            font.family: Theme.font
                            font.pixelSize: 17
                            color: Theme.fg
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: bat.modelData.name
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.fg
                            }

                            Text {
                                visible: bat.modelData.charging
                                text: root.glyph(0xF0084)
                                font.family: Theme.font
                                font.pixelSize: 12
                                color: Theme.green
                            }

                            Text {
                                text: Math.round(bat.modelData.percent) + "%"
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                color: bat.tint
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6
                            radius: 0
                            color: Theme.hover

                            Rectangle {
                                width: Math.max(parent.height, parent.width * Math.min(100, bat.modelData.percent) / 100)
                                height: parent.height
                                radius: 0
                                color: bat.tint
                            }
                        }
                    }
                }
            }
        }

        // Drives
        Card {
            title: "Drives"
            spacing: 12

            Text {
                Layout.fillWidth: true
                visible: !Devices.udisks
                text: "Install udisks2 to mount and eject drives"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }

            Repeater {
                model: Devices.drives

                RowLayout {
                    id: drv

                    required property var modelData
                    readonly property bool mounted: modelData.mounts.length > 0
                    readonly property real ratio: modelData.total > 0 ? modelData.used / modelData.total : 0
                    readonly property bool busy: Devices.busy === modelData.path

                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        text: root.glyph(drv.modelData.removable && !drv.modelData.system ? 0xF0553 : 0xF02CA)
                        font.family: Theme.font
                        font.pixelSize: 17
                        color: drv.mounted ? Theme.accent : Theme.dim
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: drv.modelData.name
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                color: drv.mounted ? Theme.fg : Theme.dim
                            }

                            Text {
                                text: drv.mounted
                                    ? SysStats.bytes(drv.modelData.used, 0) + " / " + SysStats.bytes(drv.modelData.total, 0)
                                    : SysStats.bytes(drv.modelData.size, 0)
                                font.family: Theme.font
                                font.pixelSize: 11
                                color: Theme.dim
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: drv.mounted
                            implicitHeight: 6
                            radius: 0
                            color: Theme.hover

                            Rectangle {
                                width: Math.max(parent.height, parent.width * drv.ratio)
                                height: parent.height
                                radius: 0
                                color: drv.ratio >= 0.9 ? Theme.danger : drv.ratio >= 0.75 ? Theme.warn : Theme.accent
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: [drv.modelData.fstype, drv.mounted ? drv.modelData.mounts.join(", ") : "not mounted",
                                   drv.modelData.name !== drv.modelData.model ? drv.modelData.model : ""].filter(s => s).join("  ·  ")
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 10
                            color: Theme.border
                        }
                    }

                    // Actions (system mounts are left alone)
                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        visible: Devices.udisks && !drv.modelData.system
                        enabled: !drv.busy
                        icon: root.glyph(drv.mounted ? (drv.modelData.removable ? 0xF01EA : 0xF0D58) : 0xF12E3)
                        label: drv.busy ? "…" : drv.mounted ? (drv.modelData.removable ? "Eject" : "Unmount") : "Mount"
                        onClicked: drv.mounted
                            ? (drv.modelData.removable ? Devices.eject(drv.modelData) : Devices.unmount(drv.modelData))
                            : Devices.mount(drv.modelData)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Devices.error !== ""
                text: Devices.error
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.danger
            }
        }

        // Fans
        Card {
            title: "Fans"
            spacing: 10

            FanRow {
                visible: !!root.gpu
                label: "GPU"
                source: root.gpu?.name ?? ""
                value: Math.round(root.gpu?.fan ?? 0) + "%"
                spinning: (root.gpu?.fan ?? 0) > 0
            }

            Repeater {
                model: Devices.fans

                FanRow {
                    required property var modelData
                    label: modelData.label
                    source: modelData.source
                    value: modelData.rpm + " RPM"
                    spinning: modelData.rpm > 0
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Devices.fans.length === 0
                text: "No motherboard fan sensors. " + (Devices.board.startsWith("Gigabyte")
                    ? "Gigabyte boards need the it87 driver (AUR: it87-dkms-git)."
                    : "Load your board's Super I/O driver (try sensors-detect).")
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }
    }

    component FanRow: RowLayout {
        id: fr

        property string label
        property string source
        property string value
        property bool spinning

        Layout.fillWidth: true
        spacing: 12

        Text {
            text: root.glyph(fr.spinning ? 0xF0210 : 0xF081D)
            font.family: Theme.font
            font.pixelSize: 17
            color: fr.spinning ? Theme.accent : Theme.dim

            RotationAnimation on rotation {
                running: fr.spinning && root.visible
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1200
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: fr.label
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
                color: Theme.fg
            }

            Text {
                Layout.fillWidth: true
                visible: fr.source !== ""
                text: fr.source
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 10
                color: Theme.border
            }
        }

        Text {
            text: fr.value
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
            color: Theme.fg
        }
    }
}
