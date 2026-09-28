import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// System Properties:
//   General          98's "System: / Registered to: / Computer:" page, with the real numbers
//   Device Manager   drives (mount, unmount, eject), device batteries, fans
//   Performance      CPU, graphics, memory, disks and network as meters, and System Monitor's charts;
//                    Task Manager opens btop
Props {
    id: root

    title: "System Properties"
    icon: "computer"
    tabs: ["General", "Device Manager", "Performance"]

    Component.onCompleted: { SysStats.active = true; Devices.active = true; }
    Component.onDestruction: { SysStats.active = false; Devices.active = false; }

    readonly property var d: SysStats.data
    function bytes(n, dec) { return SysStats.bytes(n, dec ?? 1); }

    // uname, uptime, the user's full name
    property var info: ({})
    Process {
        running: true
        command: ["sh", "-c", 'echo "$(uname -r)"; . /etc/os-release; echo "$PRETTY_NAME"; getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; echo "$USER"; uname -n; cut -d. -f1 /proc/uptime']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.info = { kernel: l[0], os: l[1], name: l[2], user: l[3], host: l[4], up: parseInt(l[5]) || 0 };
            }
        }
    }
    function uptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + " day" + (d > 1 ? "s, " : ", ") : "") + h + " hr " + m + " min";
    }

    readonly property var upowerDevices: UPower.devices.values.filter(x =>
        x.isPresent && !x.isLaptopBattery && x.type !== UPowerDeviceType.LinePower && x.model)
    readonly property var btBatteries: (Bluetooth.devices?.values ?? []).filter(x =>
        x.connected && x.batteryAvailable && !upowerDevices.some(u => u.model === x.name))
    readonly property var batteries: upowerDevices.map(x => ({
        name: x.model, percent: x.percentage > 1 ? x.percentage : x.percentage * 100,
        charging: x.state === UPowerDeviceState.Charging || x.state === UPowerDeviceState.PendingCharge
    })).concat(btBatteries.map(x => ({ name: x.name, percent: x.battery > 1 ? x.battery : x.battery * 100, charging: false })))

    // ---------------------------------------------------------------- General
    Item {
        // the computer: a beige box and a monitor, drawn
        Item {
            id: pc
            width: 190; height: 180
            y: 10
            Bevel { x: 20; y: 10; width: 120; height: 96; kind: "button"; fill: Theme.face }
            Rectangle { x: 32; y: 20; width: 96; height: 74; color: Theme.desktop; border.width: 1; border.color: Theme.dkShadow }
            Bevel { x: 60; y: 106; width: 40; height: 8; kind: "button"; fill: Theme.face }
            Bevel { x: 0; y: 118; width: 170; height: 40; kind: "button"; fill: Theme.face }
            Rectangle { x: 12; y: 128; width: 50; height: 5; color: Theme.shadow }
            Rectangle { x: 12; y: 138; width: 50; height: 5; color: Theme.shadow }
            Rectangle { x: 150; y: 132; width: 6; height: 4; color: "#00c000" }
        }
        Column {
            x: pc.width + 20
            y: 12
            width: parent.width - x
            spacing: 2
            Txt { text: "System:" }
            Txt { leftPadding: 24; text: root.info.os ?? "Linux" }
            Txt { leftPadding: 24; text: "Linux " + (root.info.kernel ?? "") }
            Txt { leftPadding: 24; text: "Memphis (a Hyprland setup)" }
            Item { width: 1; height: 12 }
            Txt { text: "Registered to:" }
            Txt { leftPadding: 24; text: root.info.name || root.info.user || "" }
            Txt { leftPadding: 24; text: root.info.host ?? "" }
            Item { width: 1; height: 12 }
            Txt { text: "Computer:" }
            Txt { leftPadding: 24; width: parent.width; elide: Text.ElideRight; text: root.d?.cpu?.name ?? "" }
            Txt { leftPadding: 24; width: parent.width; elide: Text.ElideRight; text: root.d?.gpu?.name ?? "" }
            Txt { leftPadding: 24; text: root.d ? root.bytes(root.d.mem.total, 1) + " RAM" : "" }
            Item { width: 1; height: 12 }
            Txt { text: "Up for " + root.uptime(root.info.up ?? 0) }
        }
    }

    // ---------------------------------------------------------------- Device Manager
    Column {
        spacing: 8
        Txt { text: "Disk drives:" }
        ListBox {
            id: drives
            width: parent.width
            height: 190
            model: Devices.drives
            currentIndex: 0
            iconOf: x => x.system ? "drive-harddisk-system" : x.removable ? "drive-removable-media" : "drive-harddisk"
            columns: [
                { title: "Drive", width: 0, text: x => x.name + (x.mounts.length ? "  (" + x.mounts[0] + ")" : "") },
                { title: "Type", width: 64, text: x => x.fstype },
                { title: "Size", width: 86, text: x => root.bytes(x.size, 0) },
                { title: "Used", width: 76, text: x => x.total > 0 ? Math.round(x.used / x.total * 100) + "%" : "" },
            ]
        }
        Row {
            spacing: 6
            readonly property var sel: Devices.drives[drives.currentIndex] ?? null
            Btn { text: "Mount"; enabled: !!parent.sel && !parent.sel.mounts.length && Devices.udisks && Devices.busy === ""; onClicked: Devices.mount(parent.sel) }
            Btn { text: "Unmount"; enabled: !!parent.sel && parent.sel.mounts.length > 0 && !parent.sel.system && Devices.busy === ""; onClicked: Devices.unmount(parent.sel) }
            Btn { text: "Eject"; enabled: !!parent.sel && parent.sel.removable && !parent.sel.system && Devices.busy === ""; onClicked: Devices.eject(parent.sel) }
            Btn { text: "Open"; enabled: !!parent.sel && parent.sel.mounts.length > 0; onClicked: Quickshell.execDetached(["thunar", parent.sel.mounts[0]]) }
        }
        Txt { visible: Devices.error !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Devices.error }
        Txt { text: "Batteries:" }
        ListBox {
            width: parent.width
            height: Math.max(1, Math.min(3, root.batteries.length)) * (Theme.menuItem - 2) + 6
            model: root.batteries
            iconOf: b => b.charging ? "battery-good-charging" : "battery-good"
            textOf: b => b.name + ": " + Math.round(b.percent) + "%" + (b.charging ? " (charging)" : "")
        }
        Txt { text: "Fans:" }
        ListBox {
            width: parent.width
            height: parent.height - y
            model: Devices.fans
            iconOf: f => "preferences-system"
            columns: [
                { title: "Fan", width: 0, text: f => f.label + "  (" + f.source.split("_")[0] + ")" },
                { title: "Speed", width: 110, text: f => f.rpm > 0 ? f.rpm + " RPM" : "Stopped" },
            ]
        }
    }

    // ---------------------------------------------------------------- Performance
    Column {
        spacing: 6
        Column {
            spacing: 6
            Repeater {
                model: root.d ? [
                    ["Processor", root.d.cpu.usage / 100, Math.round(root.d.cpu.usage) + "%" + (root.d.cpu.temp ? ", " + Math.round(root.d.cpu.temp) + "°C" : "")],
                    ["Graphics", (root.d.gpu?.usage ?? 0) / 100, root.d.gpu ? Math.round(root.d.gpu.usage) + "%, " + Math.round(root.d.gpu.temp) + "°C" : "—"],
                    ["Memory", root.d.mem.used / root.d.mem.total, root.bytes(root.d.mem.used) + " of " + root.bytes(root.d.mem.total, 0)],
                    ["Video memory", root.d.gpu ? root.d.gpu.memUsed / root.d.gpu.memTotal : 0, root.d.gpu ? root.bytes(root.d.gpu.memUsed) + " of " + root.bytes(root.d.gpu.memTotal, 0) : "—"],
                ].concat(root.d.disks.map(k => ["Disk " + k.mount, k.used / k.size, root.bytes(k.used, 0) + " of " + root.bytes(k.size, 0)])) : []
                Item {
                    required property var modelData
                    width: root.width - 40
                    height: 24
                    Txt { width: 116; height: parent.height; text: modelData[0] + ":" }
                    Progress {
                        x: 120
                        width: 210
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        value: modelData[1]
                        color: modelData[1] > 0.9 ? Theme.danger : Theme.select
                    }
                    Txt { x: 340; height: parent.height; text: modelData[2] }
                }
            }
        }
        // System Monitor
        Row {
            spacing: 8
            Column {
                spacing: 2
                Txt { text: "Processor usage" }
                Bevel { kind: "sunken"; width: 226; height: 92; Chart { anchors.fill: parent; anchors.margins: 2; values: SysStats.cpuHistory } }
            }
            Column {
                spacing: 2
                Txt { text: "Graphics usage" }
                Bevel { kind: "sunken"; width: 226; height: 92; Chart { anchors.fill: parent; anchors.margins: 2; values: SysStats.gpuHistory; line: "#00ffff" } }
            }
        }
        Column {
            spacing: 2
            Txt { text: "Network: " + (root.d ? "down " + root.bytes(root.d.net.rx) + "/s, up " + root.bytes(root.d.net.tx) + "/s" : "") }
            Bevel {
                kind: "sunken"; width: 460; height: 70
                Chart { anchors.fill: parent; anchors.margins: 2; values: SysStats.rxHistory; max: 0 }
            }
        }
        Row {
            spacing: 8
            Txt { height: Theme.button; text: root.d ? root.d.procs + " processes running" : "" }
            Btn { text: "Task Manager…"; onClicked: Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]) }
        }
    }
}
