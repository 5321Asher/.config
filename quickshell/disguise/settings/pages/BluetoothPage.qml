import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Bluetooth & devices: the radio, your devices (connect, disconnect, remove), adding a device
// (look for new ones, pick one to pair), then device batteries and the fans.
Column {
    id: root
    spacing: 4
    Component.onCompleted: Devices.active = true
    Component.onDestruction: { Devices.active = false; if (adapter?.discovering) adapter.discovering = false; }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devs: (adapter?.devices.values ?? []).filter(d => d.name && d.name !== d.address.replace(/:/g, "-"))
    readonly property var paired: devs.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devs.filter(d => !d.paired && !d.bonded)
    readonly property var batteries: UPower.devices.values.filter(x => x.isPresent && !x.isLaptopBattery && x.type !== UPowerDeviceType.LinePower && x.model)
        .map(x => ({ name: x.model, pct: x.percentage > 1 ? x.percentage : x.percentage * 100 }))
        .concat(devs.filter(d => d.connected && d.batteryAvailable).map(d => ({ name: d.name, pct: d.battery > 1 ? d.battery : d.battery * 100 })))
    function icon(d) {
        const i = (d.icon ?? "").toLowerCase();
        return i.includes("head") || i.includes("audio") ? "" : i.includes("mouse") ? "" : i.includes("keyboard") ? ""
             : i.includes("phone") ? "" : i.includes("game") ? "" : "";
    }

    SettingRow {
        width: parent.width
        glyph: ""; title: "Bluetooth"; subtitle: !root.adapter ? "No Bluetooth adapter" : root.adapter.enabled ? "Discoverable as \"" + (root.adapter.name ?? "") + "\"" : "Off"
        Toggle { enabled: !!root.adapter; checked: root.adapter?.enabled ?? false; onToggled: root.adapter.enabled = !root.adapter.enabled }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Add device"; subtitle: root.adapter?.discovering ? "Looking for devices… make yours discoverable" : "Bluetooth: mice, keyboards, pens, audio…"
        Btn { kind: "accent"; text: root.adapter?.discovering ? "Stop" : "Add device"; enabled: root.adapter?.enabled ?? false; onClicked: root.adapter.discovering = !root.adapter.discovering }
    }
    Repeater {
        model: root.adapter?.discovering ? root.nearby : []
        SettingRow {
            required property var modelData
            width: root.width
            glyph: root.icon(modelData); title: modelData.name; subtitle: modelData.pairing ? "Pairing…" : "Not paired"
            Btn { text: "Pair"; enabled: !modelData.pairing; onClicked: { modelData.trusted = true; modelData.pair(); } }
        }
    }

    Header { text: "Devices" }
    SettingRow { visible: root.paired.length === 0; width: parent.width; glyph: ""; title: "No devices paired yet" }
    Repeater {
        model: (root.adapter?.enabled ?? false) ? root.paired : []
        SettingRow {
            required property var modelData
            width: root.width
            glyph: root.icon(modelData)
            title: modelData.name
            subtitle: modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : modelData.connected
                ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round((modelData.battery > 1 ? modelData.battery : modelData.battery * 100)) + "% battery" : "") : "Paired"
            Row {
                spacing: 6
                Btn { text: modelData.connected ? "Disconnect" : "Connect"; onClicked: modelData.connected ? modelData.disconnect() : modelData.connect() }
                Btn { kind: "subtle"; glyph: ""; width: 36; onClicked: modelData.forget() }
            }
        }
    }

    Header { text: "Batteries"; visible: root.batteries.length > 0 }
    Repeater {
        model: root.batteries
        SettingRow {
            required property var modelData
            width: root.width
            glyph: String.fromCharCode(0xeba0 + Math.round(modelData.pct / 10)); title: modelData.name
            Txt { height: 32; text: Math.round(modelData.pct) + "%"; level: 2 }
        }
    }
    Header { text: "Fans"; visible: Devices.fans.length > 0 }
    Repeater {
        model: Devices.fans
        SettingRow {
            required property var modelData
            width: root.width
            glyph: ""; title: modelData.label; subtitle: modelData.source
            Txt { height: 32; text: modelData.rpm > 0 ? modelData.rpm + " RPM" : "Stopped"; level: 2 }
        }
    }
    Header { text: "Related" }
    SettingRow { width: parent.width; glyph: ""; title: "Drives"; subtitle: "Mount, eject and open your disks"; clickable: true; onClicked: SettingsApp.go("storage") }
}
