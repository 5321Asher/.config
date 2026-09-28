import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../../theme"
import "../../widgets"
import "../../services"

// 07 HANGAR 格納庫: device batteries (UPower and Bluetooth), drives (mount, unmount, eject, open),
// fans.
Column {
    id: root

    spacing: 22
    Component.onCompleted: Devices.active = true
    Component.onDestruction: Devices.active = false

    readonly property var upowerDevices: UPower.devices.values.filter(d => d.isPresent && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.model)
    readonly property var btDevices: (Bluetooth.devices?.values ?? []).filter(d => d.connected && d.batteryAvailable && !upowerDevices.some(u => u.model === d.name))
    readonly property var batteries: upowerDevices.map(d => ({ name: d.model, percent: d.percentage > 1 ? d.percentage : d.percentage * 100,
        charging: d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge }))
        .concat(btDevices.map(d => ({ name: d.name, percent: d.battery > 1 ? d.battery : d.battery * 100, charging: false })))
    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + "T" : Math.round(b / 1e9) + "G"; }

    Section {
        title: "batteries"
        jp: "電池"
        Label { visible: root.batteries.length === 0; text: "// no battery devices reporting" }
        Repeater {
            model: root.batteries
            Column {
                required property var modelData
                width: parent.width
                spacing: 4
                KV { key: modelData.name; value: Math.round(modelData.percent) + "%" + (modelData.charging ? " // charging" : "")
                     color: modelData.percent < 20 ? Theme.red : Theme.cyan }
                Blocks { count: 20; blockWidth: (root.width - 19 * 2) / 20; blockHeight: 6; value: modelData.percent / 100
                         color: modelData.percent < 20 ? Theme.red : Theme.cyan }
            }
        }
    }

    Section {
        title: "drives"
        jp: "記憶装置"
        trailing: Devices.busy ? "working…" : ""
        Label { visible: Devices.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Devices.error; color: Theme.red }
        Repeater {
            model: Devices.drives
            Row2 {
                required property var modelData
                glyph: modelData.system ? "\u{f02ca}" : modelData.removable ? "\u{f07ef}" : "\u{f02ca}"
                title: modelData.name + (modelData.mounts.length ? "  " + modelData.mounts[0] : "")
                subtitle: modelData.model + " // " + modelData.fstype + " // " + root.gb(modelData.size)
                    + (modelData.total > 0 ? " // " + Math.round(modelData.used / modelData.total * 100) + "% used" : "")
                active: modelData.mounts.length > 0
                Btn { visible: !modelData.mounts.length && Devices.udisks; text: "mount"; enabled: Devices.busy === ""; onClicked: Devices.mount(modelData) }
                Btn { visible: modelData.mounts.length > 0 && !modelData.system; text: "unmount"; enabled: Devices.busy === ""; onClicked: Devices.unmount(modelData) }
                Btn { visible: modelData.removable && !modelData.system; text: "eject"; enabled: Devices.busy === ""; onClicked: Devices.eject(modelData) }
                Btn { visible: modelData.mounts.length > 0; text: "open"; onClicked: Quickshell.execDetached(["thunar", modelData.mounts[0]]) }
            }
        }
    }

    Section {
        title: "fans"
        jp: "冷却"
        trailing: Devices.board
        Repeater {
            model: Devices.fans
            KV { required property var modelData; key: modelData.label + "  //  " + modelData.source.split("_")[0]
                 value: modelData.rpm > 0 ? modelData.rpm + " RPM" : "stopped"; color: modelData.rpm > 0 ? Theme.cyan : Theme.dim }
        }
    }
}
