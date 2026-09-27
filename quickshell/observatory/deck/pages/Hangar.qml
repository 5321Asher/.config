import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../../theme"
import "../../services"
import ".."

// Hangar: peripheral batteries (UPower and Bluetooth), drives (mount, unmount, eject via udisksctl;
// services/Devices.qml) and fans.
Column {
    id: root

    spacing: 22

    Component.onCompleted: { Devices.active = true; Devices.refresh(); }
    Component.onDestruction: Devices.active = false

    // ---------------------------------------------------------------- batteries
    readonly property var upowerDevices: UPower.devices.values.filter(d =>
        d.isPresent && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.model)
    readonly property var btDevices: (Bluetooth.devices?.values ?? []).filter(d =>
        d.connected && d.batteryAvailable && !upowerDevices.some(u => u.model === d.name))
    readonly property var batteries: upowerDevices.map(d => ({
        name: d.model,
        kind: UPowerDeviceType.toString(d.type).toLowerCase(),
        percent: d.percentage > 1 ? d.percentage : d.percentage * 100,
        charging: d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge
    })).concat(btDevices.map(d => ({
        name: d.name,
        kind: "bluetooth",
        percent: d.battery > 1 ? d.battery : d.battery * 100,
        charging: false
    })))

    function bytes(n) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1000 && i < u.length - 1) { n /= 1000; i++; }
        return (i ? n.toFixed(n < 10 ? 1 : 0) : n) + " " + u[i];
    }

    Section {
        title: "cells"
        trailing: root.batteries.length + " reporting"
        Text {
            visible: root.batteries.length === 0
            text: "no battery-powered devices reporting"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSize
        }
        Repeater {
            model: root.batteries
            Item {
                required property var modelData
                width: parent.width
                height: 40
                readonly property bool low: modelData.percent <= 15
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - cell.width - 12
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: modelData.name
                        color: Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize
                    }
                    Text {
                        text: modelData.kind + (modelData.charging ? "  ·  charging" : "")
                        color: modelData.charging ? Theme.phosphor : Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                    }
                }
                // A brass battery cell, filled in phosphor (signal red when low)
                Item {
                    id: cell
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110
                    height: 22
                    Rectangle {
                        width: parent.width - 5
                        height: parent.height
                        radius: 3
                        color: Theme.alpha(Theme.bgDark, 0.9)
                        border.width: 1.2
                        border.color: Theme.brass
                        Rectangle {
                            x: 3; y: 3
                            height: parent.height - 6
                            width: Math.max(2, (parent.width - 6) * Math.min(1, modelData.percent / 100))
                            radius: 1.5
                            color: parent.parent.parent.low ? Theme.signal : Theme.phosphor
                            opacity: 0.85
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Math.round(modelData.percent) + "%"
                            color: Theme.starlight
                            style: Text.Outline
                            styleColor: Theme.bgDark
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall
                            font.weight: Font.DemiBold
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 9; radius: 1
                        color: Theme.brass
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- drives
    Section {
        title: "drives"
        trailing: Devices.busy ? Devices.busy.toLowerCase() : Devices.udisks ? "" : "udisks2 not found"
        trailingColor: Devices.busy ? Theme.phosphor : Theme.warn
        Text {
            visible: Devices.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: Devices.error
            color: Theme.signal
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Repeater {
            model: Devices.drives
            Item {
                id: drive
                required property var modelData
                readonly property bool mounted: modelData.mounts.length > 0
                readonly property real f: modelData.total > 0 ? modelData.used / modelData.total : 0
                width: parent.width
                height: 58
                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: Theme.alpha(Theme.bgDark, 0.7)
                    border.width: 1
                    border.color: drive.mounted ? Theme.alpha(Theme.brass, 0.7) : Theme.alpha(Theme.border, 0.9)
                }
                Text {
                    id: dg
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.removable ? "\u{f07c0}" : "\u{f02ca}"
                    color: drive.mounted ? Theme.brass : Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: 20
                }
                Column {
                    anchors.left: dg.right
                    anchors.leftMargin: 12
                    anchors.right: acts.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (modelData.mounts[0] ?? modelData.name) + (modelData.system ? "  · system" : "")
                        color: Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: modelData.model + "  ·  " + modelData.fstype + "  ·  " + (drive.mounted && modelData.total > 0
                            ? root.bytes(modelData.used) + " / " + root.bytes(modelData.total) : root.bytes(modelData.size))
                        color: Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                    }
                    Rectangle {
                        visible: drive.mounted && modelData.total > 0
                        width: parent.width
                        height: 3
                        radius: 1.5
                        color: Theme.alpha(Theme.border, 0.8)
                        Rectangle {
                            width: parent.width * drive.f
                            height: parent.height
                            radius: 1.5
                            color: drive.f > 0.9 ? Theme.signal : Theme.phosphor
                        }
                    }
                }
                Row {
                    id: acts
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    visible: !modelData.system
                    Link { visible: !drive.mounted; text: "mount"; onClicked: Devices.mount(drive.modelData) }
                    Link { visible: drive.mounted; text: "open"; onClicked: { DeckState.open = false; Quickshell.execDetached(["xdg-open", drive.modelData.mounts[0]]); } }
                    Link { visible: drive.mounted; text: "unmount"; onClicked: Devices.unmount(drive.modelData) }
                    Link { visible: modelData.removable; text: "eject"; danger: true; onClicked: Devices.eject(drive.modelData) }
                }
            }
        }
    }

    // ---------------------------------------------------------------- fans
    Section {
        title: "fans"
        trailing: Devices.board.toLowerCase()
        Text {
            visible: Devices.fans.length === 0
            text: "no fan sensors"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSize
        }
        Grid {
            width: parent.width
            columns: 3
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: Devices.fans
                Item {
                    required property var modelData
                    width: (parent.width - 20) / 3
                    height: 60
                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: Theme.alpha(Theme.bgDark, 0.7)
                        border.width: 1
                        border.color: Theme.alpha(Theme.border, 0.9)
                    }
                    // the fan glyph spins at a speed that follows the rpm
                    Text {
                        id: fg
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{f0210}"
                        color: modelData.rpm > 0 ? Theme.phosphor : Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: 22
                        RotationAnimation on rotation {
                            running: modelData.rpm > 0
                            from: 0; to: 360
                            loops: Animation.Infinite
                            duration: Math.max(400, 2400000 / Math.max(1, modelData.rpm))
                        }
                    }
                    Column {
                        anchors.left: fg.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: modelData.label.toLowerCase()
                            color: Theme.brass
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall + 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: modelData.rpm > 0 ? modelData.rpm + " rpm" : "stopped"
                            color: Theme.fg
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall
                        }
                    }
                }
            }
        }
    }
}
