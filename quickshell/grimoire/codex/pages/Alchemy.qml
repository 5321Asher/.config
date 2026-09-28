import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// VI. Alchemy: the reagents in full: the processor (its threads, load, heat, pace), the graphics,
// memory and swap, the stores (disks), the network's comings and goings, and the wards: the
// vulnerability watch (arch-audit) and the updates waiting (checkupdates), with "update now" and
// btop for the rest.
Column {
    id: root

    spacing: 22
    Component.onCompleted: SysStats.active = true
    readonly property var d: SysStats.data
    function gb(b) { return (b / 1073741824).toFixed(1) + " GB"; }
    function heat(t) { return t >= 80 ? Theme.danger : t >= 60 ? Theme.warn : Theme.ink; }

    Section {
        title: "the processor"
        trailing: root.d ? (root.d.cpu.name ?? "") : ""
        Trace { width: parent.width; height: 54; values: SysStats.cpuHistory; max: 100; color: Theme.arcane }
        Row {
            width: parent.width
            spacing: 3
            Repeater { model: root.d?.cpu?.threads ?? []
                Rectangle { required property var modelData
                            width: (root.width - ((root.d?.cpu?.threads ?? []).length - 1) * 3) / Math.max(1, (root.d?.cpu?.threads ?? []).length)
                            height: 8; radius: 2
                            color: modelData > 85 ? Theme.danger : Theme.alpha(Theme.arcane, 0.2 + modelData / 120) } }
        }
        KV { key: "at work"; value: Math.round(root.d?.cpu?.usage ?? 0) + "% · load " + (root.d?.cpu?.load ?? []).join(" ") }
        KV { key: "heat"; value: Math.round(root.d?.cpu?.temp ?? 0) + "°C"; color: root.heat(root.d?.cpu?.temp ?? 0) }
        KV { key: "pace"; value: (root.d?.cpu?.freq ?? 0).toFixed(2) + " GHz" }
        KV { key: "processes"; value: String(root.d?.procs ?? "") }
    }

    Section {
        visible: !!root.d?.gpu
        title: "the graphics"
        trailing: root.d?.gpu?.name ?? ""
        Trace { width: parent.width; height: 44; values: SysStats.gpuHistory; max: 100; color: Theme.rubric }
        KV { key: "at work"; value: Math.round(root.d?.gpu?.usage ?? 0) + "%" }
        KV { key: "heat"; value: Math.round(root.d?.gpu?.temp ?? 0) + "°C"; color: root.heat(root.d?.gpu?.temp ?? 0) }
        KV { key: "its memory"; value: root.d?.gpu ? root.gb(root.d.gpu.memUsed) + " of " + root.gb(root.d.gpu.memTotal) : "" }
        KV { key: "power"; value: root.d?.gpu ? Math.round(root.d.gpu.power) + " of " + Math.round(root.d.gpu.powerLimit) + " W" : "" }
    }

    Section {
        title: "memory"
        trailing: root.d ? root.gb(root.d.mem.used) + " of " + root.gb(root.d.mem.total) : ""
        Meter { width: parent.width; height: 10; color: Theme.green; hot: 0.9; value: root.d ? root.d.mem.used / root.d.mem.total : 0 }
        KV { visible: (root.d?.mem?.swapTotal ?? 0) > 0; key: "swap"; value: root.d ? root.gb(root.d.mem.swapUsed) + " of " + root.gb(root.d.mem.swapTotal) : "" }
    }

    Section {
        title: "the stores"
        Repeater {
            model: root.d?.disks ?? []
            Column {
                required property var modelData
                width: parent.width
                spacing: 4
                KV { key: modelData.mount; value: root.gb(modelData.used) + " of " + root.gb(modelData.size) }
                Meter { width: parent.width; hot: 0.9; value: modelData.used / modelData.size }
            }
        }
    }

    Section {
        title: "comings and goings"
        trailing: root.d?.net?.iface ?? ""
        Item { width: parent.width; height: 50
            Trace { anchors.fill: parent; values: SysStats.txHistory; color: Theme.rubric; fill: false }
            Trace { anchors.fill: parent; values: SysStats.rxHistory; color: Theme.goldDeep } }
        KV { key: "going out"; value: SysStats.bytes(root.d?.net?.tx ?? 0) + "/s"; color: Theme.rubric }
        KV { key: "coming in"; value: SysStats.bytes(root.d?.net?.rx ?? 0) + "/s"; color: Theme.goldDeep }
    }

    Section {
        title: "the wards"
        trailing: Updates.auditing || Updates.checking ? "inspecting…" : Updates.ago() ? "inspected " + Updates.ago() : ""
        Body {
            width: parent.width
            wrapMode: Text.Wrap
            text: !Updates.auditAvailable ? "The wards cannot be inspected: install arch-audit."
                : Updates.count === 0 ? "The wards hold. No known curses touch this machine."
                : Updates.count + " packages bear known curses (" + Updates.high + " grave), " + (Updates.fixable ? Updates.fixable + " lifted by an update." : "none yet with a cure.")
            color: Updates.high > 0 ? Theme.rubric : Theme.ink
        }
        Repeater {
            model: Updates.vulns.slice(0, 8)
            KV { required property var modelData; key: modelData.name + (modelData.fix ? " · cure ready" : "")
                 value: modelData.severity.toLowerCase() + " · " + modelData.cves + (modelData.cves === 1 ? " curse" : " curses")
                 color: modelData.severity === "Critical" || modelData.severity === "High" ? Theme.rubric : Theme.ink }
        }
        KV { key: "updates waiting"; value: Updates.pendingAvailable ? String(Updates.pending) : "install pacman-contrib" }
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: "update now"; primary: true; enabled: Updates.pending > 0; onClicked: { CodexState.open = false; Updates.update(); } }
            Btn { text: "inspect again"; onClicked: Updates.sweep() }
            Btn { text: "open btop"; onClicked: { CodexState.open = false; Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]); } }
        }
    }

    // a line of ink over the last minute, with a faint wash under it
    component Trace: Canvas {
        id: tr
        property var values: []
        property real max: 0
        property color color: Theme.gold
        property bool fill: true
        onValuesChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const v = values, n = 60;
            if (!v.length) return;
            const top = max > 0 ? max : Math.max(1, ...v) * 1.15;
            const px = i => width - (v.length - 1 - i) * width / (n - 1);
            const py = x => height - 2 - Math.min(1, x / top) * (height - 4);
            ctx.beginPath();
            v.forEach((x, i) => i ? ctx.lineTo(px(i), py(x)) : ctx.moveTo(px(i), py(x)));
            ctx.strokeStyle = color;
            ctx.lineWidth = 1.6;
            ctx.lineJoin = "round";
            ctx.stroke();
            if (fill) {
                ctx.lineTo(px(v.length - 1), height);
                ctx.lineTo(px(0), height);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(color, 0.14);
                ctx.fill();
            }
            ctx.strokeStyle = Qt.alpha(Theme.inkDim, 0.35);
            ctx.lineWidth = 1;
            ctx.beginPath(); ctx.moveTo(0, height - 0.5); ctx.lineTo(width, height - 0.5); ctx.stroke();
        }
    }
}
