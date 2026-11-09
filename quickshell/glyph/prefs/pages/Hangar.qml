import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../../theme"
import "../../widgets"
import "../../services"

// DEVICES: device batteries (UPower and Bluetooth) as rings of dots, drives (mount, unmount, eject,
// open), fans.
Column {
    id: root

    spacing: 40
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
        
        Lb { visible: root.batteries.length === 0; text: "no battery devices reporting" }
        Flow {
            width: parent.width
            spacing: 30
            Repeater {
                model: root.batteries
                Item {
                    required property var modelData
                    width: 170
                    height: 210
                    Ring { width: 170; height: 170; n: 40; dot: 5; f: modelData.percent / 100; on: modelData.percent < 20 ? Theme.red : Theme.fg }
                    Column {
                        x: 0; width: 170; y: 85 - height / 2
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.charging ? "\u{F0084}" : "\u{F02CB}"; font.pixelSize: 18 }
                        Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 6; text: Math.round(modelData.percent); font.pixelSize: 54 }
                    }
                    Lb { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom } width: 170; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.name; px: 10 }
                }
            }
        }
    }

    Section {
        title: "drives"
        
        trailing: Devices.busy ? "working…" : ""
        Lb { visible: Devices.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Devices.error; color: Theme.red }
        Repeater {
            model: Devices.drives
            Row2 {
                required property var modelData
                glyph: modelData.system ? "\u{f02ca}" : modelData.removable ? "\u{f07ef}" : "\u{f02ca}"
                title: modelData.name + (modelData.mounts.length ? "  " + modelData.mounts[0] : "")
                subtitle: modelData.model + " · " + modelData.fstype + " · " + root.gb(modelData.size)
                    + (modelData.total > 0 ? " · " + Math.round(modelData.used / modelData.total * 100) + "% used" : "")
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
        Repeater {
            model: Devices.fans
            KV { required property var modelData; key: modelData.label + "  ·  " + modelData.source.split("_")[0]
                 value: modelData.rpm > 0 ? modelData.rpm + " RPM" : "stopped"; color: modelData.rpm > 0 ? Theme.fg : Theme.grey }
        }
    }
}
