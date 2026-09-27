import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme"
import "../../services"
import ".."

// Telemetry: CPU and GPU as big dials, oscilloscope traces of their load and the network, every
// thread, memory, disks and drive temperatures. Sampled (services/SysStats.qml, scripts/stats.py)
// only while this page is open.
Column {
    id: root

    spacing: 22

    Component.onCompleted: SysStats.active = true
    Component.onDestruction: SysStats.active = false

    readonly property var d: SysStats.data
    function pct(v) { return Math.round(v ?? 0) + "%"; }
    function deg(v) { return v ? Math.round(v) + "°c" : "—"; }

    Text {
        visible: !root.d
        text: "acquiring telemetry…"
        color: Theme.dim
        font.family: Theme.fontData
        font.pixelSize: Theme.dataSize
    }

    // ---------------------------------------------------------------- dials
    Row {
        visible: !!root.d
        width: parent.width
        spacing: 16
        BigDial {
            width: (parent.width - parent.spacing) / 2
            title: "cpu"
            name: root.d?.cpu?.name ?? ""
            value: (root.d?.cpu?.usage ?? 0) / 100
            lines: [["temp", root.deg(root.d?.cpu?.temp)], ["clock", (root.d?.cpu?.freq ?? 0).toFixed(2) + " ghz"],
                    ["load", (root.d?.cpu?.load ?? []).map(x => x.toFixed(2)).join(" ")], ["procs", root.d?.procs ?? ""]]
            hot: (root.d?.cpu?.temp ?? 0) >= 85
        }
        BigDial {
            width: (parent.width - parent.spacing) / 2
            visible: !!root.d?.gpu
            title: "gpu"
            name: root.d?.gpu?.name ?? ""
            value: (root.d?.gpu?.usage ?? 0) / 100
            lines: [["temp", root.deg(root.d?.gpu?.temp)], ["clock", Math.round(root.d?.gpu?.clock ?? 0) + " mhz"],
                    ["power", Math.round(root.d?.gpu?.power ?? 0) + " / " + Math.round(root.d?.gpu?.powerLimit ?? 0) + " w"],
                    ["vram", SysStats.bytes(root.d?.gpu?.memUsed ?? 0) + " / " + SysStats.bytes(root.d?.gpu?.memTotal ?? 0)]]
            hot: (root.d?.gpu?.temp ?? 0) >= 85
        }
    }

    // ---------------------------------------------------------------- traces
    Section {
        visible: !!root.d
        title: "traces"
        trailing: "last " + SysStats.historyLength * SysStats.interval + " s"
        Trace { label: "cpu"; values: SysStats.cpuHistory; max: 100; ink: Theme.brassBright; readout: root.pct(root.d?.cpu?.usage) }
        Trace { visible: !!root.d?.gpu; label: "gpu"; values: SysStats.gpuHistory; max: 100; ink: Theme.phosphor; readout: root.pct(root.d?.gpu?.usage) }
        Trace { label: "down"; values: SysStats.rxHistory; max: 0; ink: Theme.phosphor; readout: SysStats.bytes(root.d?.net?.rx ?? 0) + "/s" }
        Trace { label: "up"; values: SysStats.txHistory; max: 0; ink: Theme.warn; readout: SysStats.bytes(root.d?.net?.tx ?? 0) + "/s" }
    }

    // ---------------------------------------------------------------- threads
    Section {
        visible: !!root.d
        title: "threads"
        trailing: (root.d?.cpu?.threads ?? []).length + " cores"
        Row {
            width: parent.width
            height: 60
            spacing: 3
            Repeater {
                model: root.d?.cpu?.threads ?? []
                Item {
                    required property real modelData
                    width: (parent.width - parent.spacing * ((root.d?.cpu?.threads ?? [1]).length - 1)) / Math.max(1, (root.d?.cpu?.threads ?? [1]).length)
                    height: parent.height
                    Rectangle { anchors.fill: parent; radius: 2; color: Theme.alpha(Theme.bgDark, 0.8); border.width: 1; border.color: Theme.alpha(Theme.border, 0.8) }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        x: 1
                        width: parent.width - 2
                        height: Math.max(1, (parent.height - 2) * modelData / 100)
                        radius: 1
                        color: modelData > 90 ? Theme.signal : Theme.phosphor
                        opacity: 0.8
                        Behavior on height { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- memory + storage
    Section {
        visible: !!root.d
        title: "memory"
        Meter {
            label: "ram"
            used: root.d?.mem?.used ?? 0
            total: root.d?.mem?.total ?? 1
        }
        Meter {
            visible: (root.d?.mem?.swapTotal ?? 0) > 0
            label: "swap"
            used: root.d?.mem?.swapUsed ?? 0
            total: root.d?.mem?.swapTotal ?? 1
        }
    }
    Section {
        visible: !!root.d
        title: "storage"
        Repeater {
            model: root.d?.disks ?? []
            Meter {
                required property var modelData
                label: modelData.mount
                used: modelData.used
                total: modelData.size
            }
        }
        Repeater {
            model: root.d?.drives ?? []
            ListRow {
                required property var modelData
                clickable: false
                glyph: "\u{f02ca}"
                title: modelData.model
                trailing: root.deg(modelData.temp)
                trailingColor: (modelData.temp ?? 0) >= 60 ? Theme.warn : Theme.phosphor
            }
        }
    }

    Link {
        text: "open btop"
        glyph: "\u{f0128}"
        onClicked: { DeckState.open = false; Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]); }
    }

    // ---------------------------------------------------------------- pieces
    // A large analog dial with the readouts under it
    component BigDial: Column {
        id: bd
        property string title
        property string name
        property real value
        property var lines: []
        property bool hot: false
        spacing: 6

        property real shown: value
        Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

        Item {
            width: parent.width
            height: 130
            Canvas {
                id: c
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = 72, r = 58;
                    const a0 = Math.PI * 0.75, sweep = Math.PI * 1.5;
                    const ang = f => a0 + sweep * Math.max(0, Math.min(1, f));
                    ctx.fillStyle = Theme.alpha(Theme.bg, 0.9);
                    ctx.beginPath(); ctx.arc(cx, cy, r + 4, 0, 2 * Math.PI); ctx.fill();
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.9);
                    ctx.lineWidth = 1.4;
                    ctx.beginPath(); ctx.arc(cx, cy, r + 4, 0, 2 * Math.PI); ctx.stroke();
                    // scale
                    for (let i = 0; i <= 50; i++) {
                        const a = ang(i / 50), big = i % 5 === 0, red = i >= 45;
                        ctx.strokeStyle = red ? Theme.alpha(Theme.signal, 0.9) : Theme.alpha(Theme.brass, big ? 0.9 : 0.45);
                        ctx.lineWidth = big ? 1.4 : 0.8;
                        const r2 = r - (big ? 9 : 5);
                        ctx.beginPath();
                        ctx.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
                        ctx.lineTo(cx + r2 * Math.cos(a), cy + r2 * Math.sin(a));
                        ctx.stroke();
                    }
                    ctx.fillStyle = Theme.alpha(Theme.dim, 0.9);
                    ctx.font = `${Theme.dataSizeSmall}px "${Theme.fontData}"`;
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    for (const f of [0.5]) {
                        const a = ang(f);
                        ctx.fillText(String(f * 100), cx + (r - 18) * Math.cos(a), cy + (r - 18) * Math.sin(a));
                    }
                    // phosphor arc of the reading
                    ctx.strokeStyle = Theme.alpha(bd.shown > 0.9 ? Theme.signal : Theme.phosphor, 0.6);
                    ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.arc(cx, cy, r - 24, ang(0), ang(bd.shown)); ctx.stroke();
                    // needle
                    const a = ang(bd.shown), nx = Math.cos(a), ny = Math.sin(a), px = -ny, py = nx, nl = r - 6;
                    ctx.fillStyle = bd.shown > 0.9 ? Theme.signal : Theme.brassBright;
                    ctx.beginPath();
                    ctx.moveTo(cx + nx * nl, cy + ny * nl);
                    ctx.lineTo(cx + px * 3, cy + py * 3);
                    ctx.lineTo(cx - nx * 9, cy - ny * 9);
                    ctx.lineTo(cx - px * 3, cy - py * 3);
                    ctx.closePath();
                    ctx.fill();
                    ctx.fillStyle = Theme.brassDeep;
                    ctx.strokeStyle = Theme.brass;
                    ctx.beginPath(); ctx.arc(cx, cy, 5, 0, 2 * Math.PI); ctx.fill(); ctx.stroke();
                }
                Connections { target: bd; function onShownChanged() { c.requestPaint(); } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 94
                text: Math.round(bd.value * 100) + "%"
                color: bd.hot || bd.value > 0.9 ? Theme.signal : Theme.starlight
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSize + 5
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 112
                text: bd.title
                color: Theme.brass
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSize + 1
                font.capitalization: Font.SmallCaps
                font.letterSpacing: Theme.labelSpacing * 2
                font.weight: Font.DemiBold
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.4; shadowOpacity: 0.45
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 14
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: bd.name
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Repeater {
            model: bd.lines
            Item {
                required property var modelData
                width: bd.width
                height: 15
                Text { text: modelData[0]; color: Theme.dim; font.family: Theme.fontData; font.pixelSize: Theme.dataSizeSmall }
                Text {
                    anchors.right: parent.right
                    text: modelData[1]
                    color: modelData[0] === "temp" && bd.hot ? Theme.signal : Theme.fg
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
        }
    }

    // An oscilloscope trace of a history, on a graticule
    component Trace: Item {
        id: tr
        property string label
        property var values: []
        property real max: 100          // 0 = scale to the largest value
        property color ink: Theme.phosphor
        property string readout
        width: parent.width
        height: 50
        Text {
            id: tl
            width: 44
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            color: Theme.brass
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
        }
        Text {
            id: tv
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 76
            horizontalAlignment: Text.AlignRight
            text: tr.readout
            color: Theme.fg
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Item {
            anchors.left: tl.right
            anchors.right: tv.left
            anchors.rightMargin: 8
            height: parent.height
            Canvas {
                id: tc
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    ctx.fillStyle = Theme.alpha(Theme.bgDark, 0.8);
                    ctx.fillRect(0, 0, w, h);
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.12);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (let i = 1; i < 4; i++) { const y = Math.round(h * i / 4) + 0.5; ctx.moveTo(0, y); ctx.lineTo(w, y); }
                    for (let i = 1; i < 10; i++) { const x = Math.round(w * i / 10) + 0.5; ctx.moveTo(x, 0); ctx.lineTo(x, h); }
                    ctx.stroke();
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.4);
                    ctx.strokeRect(0.5, 0.5, w - 1, h - 1);
                    const v = tr.values;
                    if (v.length < 2) return;
                    const top = tr.max > 0 ? tr.max : Math.max(1, ...v) * 1.15;
                    const n = SysStats.historyLength;
                    const x = i => w - (v.length - 1 - i) / (n - 1) * w;
                    const y = val => h - 2 - (h - 4) * Math.min(1, val / top);
                    ctx.beginPath();
                    ctx.moveTo(x(0), h);
                    for (let i = 0; i < v.length; i++) ctx.lineTo(x(i), y(v[i]));
                    ctx.lineTo(x(v.length - 1), h);
                    ctx.closePath();
                    ctx.fillStyle = Theme.alpha(tr.ink, 0.12);
                    ctx.fill();
                    ctx.beginPath();
                    for (let i = 0; i < v.length; i++) i ? ctx.lineTo(x(i), y(v[i])) : ctx.moveTo(x(i), y(v[i]));
                    ctx.strokeStyle = tr.ink;
                    ctx.lineWidth = 1.4;
                    ctx.stroke();
                }
                Connections { target: tr; function onValuesChanged() { tc.requestPaint(); } }
            }
        }
    }

    // used / total as a bar with readouts
    component Meter: Item {
        id: m
        property string label
        property real used
        property real total
        readonly property real f: total > 0 ? used / total : 0
        width: parent.width
        height: 30
        Text {
            id: ml
            width: 60
            elide: Text.ElideRight
            text: m.label
            color: Theme.brass
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
        }
        Text {
            anchors.right: parent.right
            text: SysStats.bytes(m.used) + " / " + SysStats.bytes(m.total) + "  ·  " + Math.round(m.f * 100) + "%"
            color: m.f > 0.9 ? Theme.signal : Theme.fg
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Rectangle {
            y: 20
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.alpha(Theme.bgDark, 0.9)
            border.width: 1
            border.color: Theme.alpha(Theme.border, 0.9)
            Rectangle {
                x: 1; y: 1
                height: parent.height - 2
                radius: 1.5
                width: Math.max(0, (parent.width - 2) * m.f)
                color: m.f > 0.9 ? Theme.signal : Theme.phosphor
                Behavior on width { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
            }
        }
    }
}
