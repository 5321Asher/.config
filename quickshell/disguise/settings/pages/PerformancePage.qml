import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Task Manager's Performance tab, as a page: the processor, memory, graphics, disks and network,
// each a card with its line chart; "Open Task Manager" runs btop.
Column {
    id: root
    spacing: 8
    Component.onCompleted: SysStats.active = true
    Component.onDestruction: SysStats.active = false
    readonly property var d: SysStats.data

    Row {
        spacing: 8
        Btn { kind: "accent"; text: "Open Task Manager"; glyph: ""; onClicked: Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]) }
        Txt { height: Theme.controlHeight; text: root.d ? root.d.procs + " processes" : "Reading…"; level: 2 }
    }
    Grid {
        width: parent.width
        columns: 2
        spacing: 8
        Meter {
            title: "CPU"; glyph: ""
            big: root.d ? Math.round(root.d.cpu.usage) + "%" : "…"
            sub: (root.d?.cpu?.name ?? "") + (root.d?.cpu?.temp ? "  ·  " + Math.round(root.d.cpu.temp) + "°C" : "")
            values: SysStats.cpuHistory; line: Theme.accent
        }
        Meter {
            visible: !!root.d?.gpu
            title: "GPU"; glyph: ""
            big: root.d?.gpu ? Math.round(root.d.gpu.usage) + "%" : "—"
            sub: (root.d?.gpu?.name ?? "No graphics statistics") + (root.d?.gpu?.temp ? "  ·  " + Math.round(root.d.gpu.temp) + "°C" : "")
            values: SysStats.gpuHistory; line: "#8764b8"
        }
        Meter {
            title: "Memory"; glyph: ""
            big: root.d ? SysStats.bytes(root.d.mem.used) + " / " + SysStats.bytes(root.d.mem.total, 0) : "…"
            sub: root.d ? Math.round(root.d.mem.used / root.d.mem.total * 100) + "% in use" : ""
            fraction: root.d ? root.d.mem.used / root.d.mem.total : 0; line: "#8b5cf6"
        }
        Meter {
            visible: !!root.d?.gpu
            title: "Video memory"; glyph: ""
            big: root.d?.gpu ? SysStats.bytes(root.d.gpu.memUsed) + " / " + SysStats.bytes(root.d.gpu.memTotal, 0) : "—"
            sub: root.d?.gpu ? Math.round(root.d.gpu.memUsed / root.d.gpu.memTotal * 100) + "% in use" : ""
            fraction: root.d?.gpu ? root.d.gpu.memUsed / root.d.gpu.memTotal : 0; line: "#c239b3"
        }
        Meter {
            title: "Network"; glyph: ""
            big: root.d ? "↓ " + SysStats.bytes(root.d.net.rx) + "/s" : "…"
            sub: root.d ? "↑ " + SysStats.bytes(root.d.net.tx) + "/s" : ""
            values: SysStats.rxHistory; line: "#c19c00"; max: 0
        }
        Repeater {
            model: root.d?.disks ?? []
            Meter {
                required property var modelData
                title: "Disk " + modelData.mount; glyph: ""
                big: Math.round(modelData.used / modelData.size * 100) + "%"
                sub: SysStats.bytes(modelData.used, 0) + " used of " + SysStats.bytes(modelData.size, 0)
                fraction: modelData.used / modelData.size; line: "#13a10e"
            }
        }
    }

    // a card: name, the big number, a line under it, and the chart (or a bar)
    component Meter: Card {
        id: m
        property string title
        property string glyph
        property string big
        property string sub
        property var values: null
        property real fraction: 0
        property color line: Theme.accent
        property real max: 100
        width: (root.width - 8) / 2
        height: 190
        Glyph { x: 16; y: 16; g: m.glyph; size: 14; color: Theme.text2 }
        Txt { x: 40; y: 12; text: m.title; strong: true }
        Txt { x: 16; y: 40; text: m.big; size: Theme.subtitle; strong: true }
        Txt { x: 16; y: 68; width: parent.width - 32; text: m.sub; size: Theme.caption; level: 2 }
        Rectangle {
            x: 16; y: 96
            width: parent.width - 32; height: parent.height - 112
            radius: Theme.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(m.line, 0.5)
            clip: true
            Canvas {
                anchors.fill: parent
                visible: m.values !== null
                property var v: m.values
                onVChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const vals = m.values ?? [];
                    if (vals.length < 2) return;
                    const top = m.max > 0 ? m.max : Math.max(1, ...vals);
                    const n = 60, step = width / (n - 1);
                    ctx.beginPath();
                    ctx.moveTo(width - (vals.length - 1) * step, height);
                    vals.forEach((x, i) => ctx.lineTo(width - (vals.length - 1 - i) * step, height - Math.min(1, x / top) * (height - 4)));
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.alpha(m.line, 0.18);
                    ctx.fill();
                    ctx.beginPath();
                    vals.forEach((x, i) => { const px = width - (vals.length - 1 - i) * step, py = height - Math.min(1, x / top) * (height - 4); i ? ctx.lineTo(px, py) : ctx.moveTo(px, py); });
                    ctx.strokeStyle = m.line;
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                }
            }
            Rectangle {
                visible: m.values === null
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * Math.max(0, Math.min(1, m.fraction))
                color: Qt.alpha(m.line, 0.25)
                Rectangle { width: parent.width; height: 1.5; color: m.line }
            }
        }
    }
}
