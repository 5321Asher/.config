import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../../theme"
import "../../widgets"
import "../../services"

// VII. Reliquary: the batteries (UPower and Bluetooth), the drives (mount, unmount, eject, open),
// the fans.
Column {
    id: root

    spacing: 22
    Component.onCompleted: Devices.active = true
    Component.onDestruction: Devices.active = false

    readonly property var upowerDevices: UPower.devices.values.filter(d => d.isPresent && d.type !== UPowerDeviceType.LinePower && (d.model || d.isLaptopBattery))
    readonly property var btDevices: (Bluetooth.devices?.values ?? []).filter(d => d.connected && d.batteryAvailable && !upowerDevices.some(u => u.model === d.name))
    readonly property var batteries: upowerDevices.map(d => ({ name: d.isLaptopBattery ? "this book's own" : d.model, percent: d.percentage > 1 ? d.percentage : d.percentage * 100,
        charging: d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.PendingCharge }))
        .concat(btDevices.map(d => ({ name: d.name, percent: d.battery > 1 ? d.battery : d.battery * 100, charging: false })))
    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : Math.round(b / 1e9) + " GB"; }

    Section {
        title: "batteries"
        Body { visible: root.batteries.length === 0; text: "No battery reports its mana."; italic: true; color: Theme.inkDim }
        Repeater {
            model: root.batteries
            Column {
                required property var modelData
                width: parent.width
                spacing: 4
                KV { key: modelData.name; value: Math.round(modelData.percent) + "%" + (modelData.charging ? " · drinking" : "")
                     color: modelData.percent < 20 ? Theme.danger : Theme.ink }
                Meter { width: parent.width; color: Theme.arcane; value: modelData.percent / 100 }
            }
        }
    }

    Section {
        title: "drives"
        trailing: Devices.busy ? "working…" : ""
        Body { visible: Devices.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Devices.error; color: Theme.danger; italic: true }
        Repeater {
            model: Devices.drives
            Row2 {
                required property var modelData
                glyph: modelData.removable ? "\u{f07ef}" : "\u{f02ca}"
                title: modelData.name + (modelData.mounts.length ? "  " + modelData.mounts[0] : "")
                subtitle: modelData.model + " · " + modelData.fstype + " · " + root.gb(modelData.size)
                    + (modelData.total > 0 ? " · " + Math.round(modelData.used / modelData.total * 100) + "% full" : "")
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
        trailing: Devices.board
        Body { visible: Devices.fans.length === 0; text: "No fan reports its turning."; italic: true; color: Theme.inkDim }
        Repeater {
            model: Devices.fans
            KV { required property var modelData; key: modelData.label + " · " + modelData.source.split("_")[0]
                 value: modelData.rpm > 0 ? modelData.rpm + " turns a minute" : "still"; color: modelData.rpm > 0 ? Theme.ink : Theme.inkDim }
        }
    }
}
