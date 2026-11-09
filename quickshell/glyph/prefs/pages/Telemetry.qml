import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// SYSTEM: the gauges as rings of dots (CPU, memory, GPU or temperature), the CPU's last two minutes
// and every core as dot matrices, memory and drives as strips, the network, and the machine's
// security: vulnerabilities (arch-audit), pending updates, the firewall, failed units; btop.
Column {
    id: root

    spacing: 40
    readonly property var d: SysStats.data
    function gb(b) { return (b / 1073741824).toFixed(1) + "G"; }
    function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/S" : Math.round(b / 1024) + " KB/S"; }

    Row {
        spacing: 34
        RingStat { f: (root.d?.cpu?.usage ?? 0) / 100; value: Math.round(root.d?.cpu?.usage ?? 0); label: `cpu · ${Math.round(root.d?.cpu?.temp ?? 0)}°` }
        RingStat { f: root.d ? root.d.mem.used / root.d.mem.total : 0; value: root.d ? Math.round(root.d.mem.used / root.d.mem.total * 100) : 0; label: root.d ? `mem · ${root.gb(root.d.mem.used)}` : "mem" }
        RingStat {
            visible: !!root.d?.gpu
            f: (root.d?.gpu?.usage ?? 0) / 100
            value: Math.round(root.d?.gpu?.usage ?? 0)
            label: `gpu · ${Math.round(root.d?.gpu?.temp ?? 0)}°`
        }
        RingStat {
            visible: !!root.d?.gpu
            f: root.d?.gpu ? root.d.gpu.memUsed / Math.max(1, root.d.gpu.memTotal) : 0
            value: Math.round(f * 100)
            label: root.d?.gpu ? `vram · ${root.gb(root.d.gpu.memUsed)}` : "vram"
        }
    }

    Section {
        title: "cpu"
        sub: "2 min"
        trailing: root.d ? `${root.d.cpu.name ?? ""} · ${(root.d.cpu.freq ?? 0).toFixed(1)} ghz` : ""
        Spark { width: parent.width; height: 90; values: SysStats.cpuHistory; max: 100; points: 60; rows: 9 }
        Lb { topPadding: 10; text: `cores · load ${(root.d?.cpu?.load ?? []).join("  ")} · ${root.d?.procs ?? 0} processes` }
        Row {
            spacing: 10
            Repeater {
                model: root.d?.cpu?.threads ?? []
                Column {
                    required property real modelData
                    spacing: 4
                    Repeater {
                        model: 8
                        Rectangle {
                            required property int index
                            readonly property int lit: Math.round(parent.modelData / 100 * 8)
                            width: 7
                            height: 7
                            radius: 3.5
                            color: 8 - index <= lit ? (8 - index === lit ? (parent.modelData > 90 ? Theme.red : Theme.fg) : Theme.grey) : Theme.s3
                        }
                    }
                }
            }
        }
    }

    Section {
        title: "memory"
        trailing: root.d ? root.gb(root.d.mem.used) + " / " + root.gb(root.d.mem.total) : ""
        Seg { width: parent.width; height: 8; n: 40; f: root.d ? root.d.mem.used / root.d.mem.total : 0 }
        KV { visible: (root.d?.mem?.swapTotal ?? 0) > 0; key: "swap"; value: root.d ? root.gb(root.d.mem.swapUsed) + " / " + root.gb(root.d.mem.swapTotal) : "" }
    }

    Section {
        title: "storage"
        Repeater {
            model: root.d?.disks ?? []
            Column {
                required property var modelData
                width: parent.width
                spacing: 8
                KV { key: modelData.mount; value: root.gb(modelData.used) + " / " + root.gb(modelData.size) }
                Seg { width: parent.width; height: 6; n: 40; f: modelData.used / modelData.size
                      on: modelData.used / modelData.size > 0.9 ? Theme.red : Theme.fg }
            }
        }
    }

    Section {
        title: "network"
        trailing: root.d?.net?.iface ?? ""
        Row {
            spacing: 60
            Row { spacing: 12; Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F0045}"; font.pixelSize: 20 }
                  Num { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.rx ?? 0).split(" ")[0]; font.pixelSize: 56 }
                  Lb { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.rx ?? 0).split(" ")[1] } }
            Row { spacing: 12; Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F005D}"; font.pixelSize: 20 }
                  Num { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.tx ?? 0).split(" ")[0]; font.pixelSize: 56 }
                  Lb { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.tx ?? 0).split(" ")[1] } }
        }
        Spark { width: parent.width; height: 60; values: SysStats.rxHistory; points: 60; rows: 6 }
    }

    Section {
        title: "security"
        trailing: Status.ice === "NOMINAL" ? "all clear" : Status.ice === "BREACHED" ? "units failed" : "no firewall"
        trailingColor: Status.ice === "NOMINAL" ? Theme.grey : Theme.red
        Row {
            spacing: 50
            Column {
                Num { text: Status.auditAvailable ? Status.vulnCount : "--"; font.pixelSize: 72; color: Status.vulnHigh ? Theme.red : Theme.fg }
                Lb { topPadding: 10; text: Status.auditAvailable ? `vulnerabilities · ${Status.vulnHigh} high` : "arch-audit missing" }
            }
            Column {
                Num { text: Status.pkgAvailable ? Status.pkgPending : "--"; font.pixelSize: 72 }
                Lb { topPadding: 10; text: Status.pkgAvailable ? "updates pending" : "pacman-contrib missing" }
            }
            Column {
                Num { text: Status.failedUnits; font.pixelSize: 72; color: Status.failedUnits ? Theme.red : Theme.fg }
                Lb { topPadding: 10; text: "failed units" }
            }
        }
        KV { key: "firewall"; value: (Status.shield || "none").toLowerCase() }
        Repeater {
            model: (Status.vulns ?? []).slice(0, 6)
            KV { required property var modelData; key: modelData.pkg ?? modelData.name ?? ""; value: [modelData.severity, modelData.fix ? "fix ready" : "", modelData.type].filter(Boolean).join(" · ").toLowerCase()
                 color: /high|critical/i.test(modelData.severity ?? "") ? Theme.red : Theme.fg }
        }
        Row {
            spacing: 10
            Btn { text: "update now"; primary: true; enabled: Status.pkgPending > 0
                  onClicked: { PrefsState.open = false; Quickshell.execDetached(["kitty", "--class", "system-update", "-e", "sh", "-c", "sudo pacman -Syu; echo; read -p 'Done. Press Enter to close. ' _"]); } }
            Btn { text: "check again"; onClicked: Status.sweep() }
            Btn { text: "open btop"; onClicked: { PrefsState.open = false; Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]); } }
        }
    }
}
