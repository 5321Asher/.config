import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// 06 TELEMETRY 遠隔測定: CPU (per thread, load, temp, clock), GPU, memory and VRAM, disks,
// network, with traces; the netrunner status (ICE, vulns, packages); btop for the rest.
Column {
    id: root

    spacing: 22
    Component.onCompleted: SysStats.active = true
    readonly property var d: SysStats.data
    function gb(b) { return (b / 1073741824).toFixed(1) + "G"; }

    Section {
        title: "cpu"
        jp: "演算"
        trailing: root.d ? (root.d.cpu.name ?? "") : ""
        Item {
            width: parent.width; height: 56
            Spark { anchors.fill: parent; values: SysStats.cpuHistory; max: 100; color: Theme.cyan; base: Theme.alpha(Theme.cyan, 0.4); points: 60 }
        }
        Row {
            width: parent.width
            spacing: 2
            Repeater { model: root.d?.cpu?.threads ?? []
                Rectangle { required property var modelData; width: (root.width - ((root.d?.cpu?.threads ?? []).length - 1) * 2) / Math.max(1, (root.d?.cpu?.threads ?? []).length)
                            height: 6; color: modelData > 85 ? Theme.red : Theme.alpha(Theme.cyan, 0.3 + modelData / 140) } }
        }
        KV { key: "load"; value: Math.round(root.d?.cpu?.usage ?? 0) + "%  //  " + (root.d?.cpu?.load ?? []).join(" "); color: Theme.cyan }
        KV { key: "temp"; value: Math.round(root.d?.cpu?.temp ?? 0) + "°C"; color: SysStats.tempColor(root.d?.cpu?.temp ?? 0) }
        KV { key: "clock"; value: (root.d?.cpu?.freq ?? 0).toFixed(2) + " GHZ" }
        KV { key: "processes"; value: String(root.d?.procs ?? "") }
    }

    Section {
        visible: !!root.d?.gpu
        title: "gpu"
        jp: "画像"
        trailing: root.d?.gpu?.name ?? ""
        Item { width: parent.width; height: 44
               Spark { anchors.fill: parent; values: SysStats.gpuHistory; max: 100; color: Theme.red; base: Theme.alpha(Theme.red, 0.4); points: 60 } }
        KV { key: "load"; value: Math.round(root.d?.gpu?.usage ?? 0) + "%"; color: Theme.red }
        KV { key: "temp"; value: Math.round(root.d?.gpu?.temp ?? 0) + "°C"; color: SysStats.tempColor(root.d?.gpu?.temp ?? 0) }
        KV { key: "vram"; value: root.d?.gpu ? root.gb(root.d.gpu.memUsed) + " / " + root.gb(root.d.gpu.memTotal) : "" }
        KV { key: "power"; value: root.d?.gpu ? Math.round(root.d.gpu.power) + " / " + Math.round(root.d.gpu.powerLimit) + " W" : "" }
    }

    Section {
        title: "memory"
        jp: "記憶"
        trailing: root.d ? root.gb(root.d.mem.used) + " / " + root.gb(root.d.mem.total) : ""
        Blocks { count: 40; blockWidth: (root.width - 39 * 2) / 40; blockHeight: 10; value: root.d ? root.d.mem.used / root.d.mem.total : 0 }
        KV { visible: (root.d?.mem?.swapTotal ?? 0) > 0; key: "swap"; value: root.d ? root.gb(root.d.mem.swapUsed) + " / " + root.gb(root.d.mem.swapTotal) : "" }
    }

    Section {
        title: "storage"
        jp: "保存"
        Repeater {
            model: root.d?.disks ?? []
            Column {
                required property var modelData
                width: parent.width
                spacing: 4
                KV { key: modelData.mount; value: root.gb(modelData.used) + " / " + root.gb(modelData.size) }
                Blocks { count: 40; blockWidth: (root.width - 39 * 2) / 40; blockHeight: 6; value: modelData.used / modelData.size
                         color: modelData.used / modelData.size > 0.9 ? Theme.red : Theme.cyan }
            }
        }
    }

    Section {
        title: "network"
        jp: "回線"
        trailing: root.d?.net?.iface ?? ""
        Item { width: parent.width; height: 50
            Spark { anchors.fill: parent; values: SysStats.txHistory; color: Theme.red; points: 60; base: Theme.alpha(Theme.line, 1) }
            Spark { anchors.fill: parent; values: SysStats.rxHistory; color: Theme.cyan; points: 60 } }
        KV { key: "▲ up"; value: SysStats.bytes(root.d?.net?.tx ?? 0) + "/s"; color: Theme.red }
        KV { key: "▼ down"; value: SysStats.bytes(root.d?.net?.rx ?? 0) + "/s"; color: Theme.cyan }
    }

    Section {
        title: "status"
        jp: "状態"
        KV { key: "ice"; value: Status.ice; color: Status.ice === "NOMINAL" ? Theme.cyan : Status.ice === "BREACHED" ? Theme.red : Theme.yellow }
        KV { key: "shield"; value: Status.shield || "none" }
        KV { key: "failed units"; value: String(Status.failedUnits); color: Status.failedUnits ? Theme.red : Theme.fg }
        KV { key: "vulnerabilities"; value: Status.auditAvailable ? Status.vulnCount + " (" + Status.vulnHigh + " high)" : "arch-audit missing"; color: Status.vulnHigh ? Theme.red : Theme.fg }
        KV { key: "updates"; value: Status.pkgAvailable ? Status.pkgPending + " pending" : "pacman-contrib missing" }
        Row {
            spacing: 8
            Btn { text: "open btop"; primary: true; onClicked: { RigState.open = false; Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]); } }
            Btn { text: "sweep"; onClicked: Status.sweep() }
        }
    }
}
