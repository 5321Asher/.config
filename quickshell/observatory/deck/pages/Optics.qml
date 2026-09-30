import QtQuick
import Quickshell
import "../../theme"
import "../../services"
import ".."

// Optics: the monitor layout (drag to arrange; edges snap), extend or mirror, and for the selected
// monitor: on/off, resolution, refresh, scale, rotation, brightness. Changes are a draft until
// applied; after applying you have Displays.confirmSeconds to keep them or they revert.
// Written to ~/.config/hypr/monitors.lua by services/Displays.qml.
Column {
    id: root

    spacing: 22

    property string selected: ""
    readonly property var mon: Displays.draft.find(m => m.name === selected) ?? Displays.draft[0] ?? null
    readonly property var enabledMonitors: Displays.draft.filter(m => m.enabled)

    Component.onCompleted: {
        Displays.refresh();
        if (!Brightness.scanned) Brightness.scan();
    }

    function ddcIndex(m) {
        if (!m) return -1;
        return Brightness.displays.findIndex(d => d.name && (m.model.includes(d.name) || m.description.includes(d.name)));
    }

    // Pending confirmation
    Rectangle {
        visible: Displays.confirming
        width: parent.width
        height: confirmCol.implicitHeight + 24
        radius: 5
        color: Theme.alpha(Theme.warn, 0.12)
        border.width: 1
        border.color: Theme.warn
        Column {
            id: confirmCol
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "keep these display settings?  reverting in " + Displays.countdown + " s"
                color: Theme.warn
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSize + 2
                font.capitalization: Font.SmallCaps
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Link { text: "revert"; onClicked: Displays.revert() }
                Link { text: "keep"; primary: true; onClicked: Displays.keep() }
            }
        }
    }

    // ---------------------------------------------------------------- layout
    Section {
        title: "arrangement"
        trailing: "drag to move"

        Item {
            id: canvas
            width: parent.width
            height: 220

            readonly property var bounds: {
                const list = root.enabledMonitors.filter(m => !m.mirror);
                if (!list.length) return { x: 0, y: 0, w: 1, h: 1 };
                const xs = [], ys = [], xe = [], ye = [];
                for (const m of list) {
                    const s = Displays.logical(m);
                    xs.push(m.x); ys.push(m.y); xe.push(m.x + s.w); ye.push(m.y + s.h);
                }
                const x = Math.min(...xs), y = Math.min(...ys);
                return { x: x, y: y, w: Math.max(...xe) - x, h: Math.max(...ye) - y };
            }
            readonly property real pad: 22
            readonly property real k: Math.min((width - pad * 2) / bounds.w, (height - pad * 2) / bounds.h)
            readonly property real ox: (width - bounds.w * k) / 2
            readonly property real oy: (height - bounds.h * k) / 2

            // A chart plate: graticule and a faint star dust
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Theme.alpha(Theme.bgDark, 0.85);
                    ctx.fillRect(0, 0, width, height);
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.1);
                    ctx.beginPath();
                    for (let x = 20; x < width; x += 20) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); }
                    for (let y = 20; y < height; y += 20) { ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); }
                    ctx.stroke();
                    let seed = 3;
                    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
                    for (let i = 0; i < 90; i++) {
                        ctx.fillStyle = Theme.alpha(Theme.starlight, 0.1 + rnd() * 0.3);
                        ctx.fillRect(rnd() * width, rnd() * height, 1, 1);
                    }
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.5);
                    ctx.strokeRect(0.5, 0.5, width - 1, height - 1);
                }
                onWidthChanged: requestPaint()
            }

            Repeater {
                model: root.enabledMonitors.filter(m => !m.mirror)

                Rectangle {
                    id: box
                    required property var modelData
                    readonly property var size: Displays.logical(modelData)
                    readonly property bool isSelected: root.mon?.name === modelData.name

                    function place() {
                        x = Qt.binding(() => canvas.ox + (modelData.x - canvas.bounds.x) * canvas.k);
                        y = Qt.binding(() => canvas.oy + (modelData.y - canvas.bounds.y) * canvas.k);
                    }
                    Component.onCompleted: place()
                    width: size.w * canvas.k
                    height: size.h * canvas.k
                    radius: 3
                    color: isSelected ? Theme.alpha(Theme.brassMuted, 0.55) : Theme.alpha(Theme.surface, 0.9)
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected ? Theme.brassBright : dragArea.containsMouse ? Theme.brass : Theme.alpha(Theme.brass, 0.5)
                    z: dragArea.drag.active ? 10 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: box.modelData.name
                            color: box.isSelected ? Theme.brassBright : Theme.fg
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall + 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: box.modelData.width + "×" + box.modelData.height
                            color: Theme.dim
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: text !== ""
                            text: Displays.draft.filter(m => m.mirror === box.modelData.name).map(m => "+ " + m.name).join(" ")
                            color: Theme.phosphor
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: box
                        drag.threshold: 4
                        onPressed: root.selected = box.modelData.name
                        // commit when the drag ends: by `released`, drag.active is already false,
                        // so a check there threw every move away
                        drag.onActiveChanged: if (!drag.active) {
                            let nx = canvas.bounds.x + (box.x - canvas.ox) / canvas.k;
                            let ny = canvas.bounds.y + (box.y - canvas.oy) / canvas.k;
                            const snap = 20 / canvas.k;
                            const me = box.size;
                            let bestX = null, bestY = null;
                            for (const o of root.enabledMonitors) {
                                if (o.name === box.modelData.name || o.mirror) continue;
                                const s = Displays.logical(o);
                                for (const c of [o.x + s.w, o.x - me.w, o.x, o.x + s.w - me.w])
                                    if (Math.abs(nx - c) < snap && (bestX === null || Math.abs(nx - c) < Math.abs(nx - bestX))) bestX = c;
                                for (const c of [o.y, o.y + s.h, o.y - me.h, o.y + s.h - me.h])
                                    if (Math.abs(ny - c) < snap && (bestY === null || Math.abs(ny - c) < Math.abs(ny - bestY))) bestY = c;
                            }
                            Displays.update(box.modelData.name, { x: Math.round(bestX ?? nx), y: Math.round(bestY ?? ny) });
                            box.place();
                        }
                    }
                }
            }
        }

        Row {
            visible: root.enabledMonitors.length > 1
            spacing: 8
            Link { text: "extend"; glyph: "\u{f0379}"; primary: !Displays.mirrored; onClicked: Displays.setMirror(false) }
            Link {
                text: "mirror " + (root.mon?.name ?? "")
                glyph: "\u{f01ab}"
                primary: Displays.mirrored
                onClicked: Displays.setMirror(true, root.mon?.mirror || root.mon?.name)
            }
        }
    }

    // Monitor picker
    Flow {
        width: parent.width
        spacing: 8
        Repeater {
            model: Displays.draft
            Link {
                required property var modelData
                glyph: "\u{f0379}"
                text: modelData.name.toLowerCase()
                primary: root.mon?.name === modelData.name
                opacity: modelData.enabled ? 1 : 0.5
                onClicked: root.selected = modelData.name
            }
        }
    }

    // ---------------------------------------------------------------- selected monitor
    Section {
        visible: !!root.mon
        title: root.mon ? root.mon.name.toLowerCase() + "  ·  " + root.mon.model.toLowerCase() : ""

        Item {
            width: parent.width
            height: 26
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mon?.mirror ? "mirroring " + root.mon.mirror : root.mon?.enabled ? "enabled" : "off"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSize
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.mon?.enabled ?? false
                // never turn off the last screen
                enabled: !(root.mon?.enabled && root.enabledMonitors.length === 1)
                onToggled: Displays.update(root.mon.name, { enabled: !root.mon.enabled, mirror: "" })
            }
        }

        Label { text: "resolution" }
        Flow {
            width: parent.width
            spacing: 6
            enabled: root.mon?.enabled ?? false
            Repeater {
                model: {
                    const seen = new Set();
                    return (root.mon?.modes ?? [])
                        .filter(m => { const k = m.width + "x" + m.height; if (seen.has(k)) return false; seen.add(k); return true; })
                        .sort((a, b) => b.width * b.height - a.width * a.height);
                }
                Link {
                    required property var modelData
                    text: modelData.width + "×" + modelData.height
                    mono: true
                    primary: root.mon && root.mon.width === modelData.width && root.mon.height === modelData.height
                    onClicked: {
                        const rates = root.mon.modes.filter(m => m.width === modelData.width && m.height === modelData.height).map(m => m.refresh);
                        Displays.update(root.mon.name, { width: modelData.width, height: modelData.height, refresh: Math.max(...rates) });
                    }
                }
            }
        }

        Label { text: "refresh" }
        Flow {
            width: parent.width
            spacing: 6
            enabled: root.mon?.enabled ?? false
            Repeater {
                model: (root.mon?.modes ?? []).filter(m => m.width === root.mon.width && m.height === root.mon.height)
                    .sort((a, b) => b.refresh - a.refresh)
                Link {
                    required property var modelData
                    text: modelData.refresh.toFixed(2) + " hz"
                    mono: true
                    primary: Math.abs((root.mon?.refresh ?? 0) - modelData.refresh) < 0.01
                    onClicked: Displays.update(root.mon.name, { refresh: modelData.refresh })
                }
            }
        }

        Label { text: "scale  ·  " + (+(root.mon?.scale ?? 1).toFixed(2)) + "×" }
        Column {
            id: scaleCol
            width: parent.width
            spacing: 8
            enabled: root.mon?.enabled ?? false
            // Hyprland only takes scales that are multiples of 1/120 and give whole-pixel logical sizes
            readonly property var validScales: {
                const w = root.mon?.width ?? 0, h = root.mon?.height ?? 0;
                const out = [];
                for (let i = 30; i <= 360; i++)
                    if ((w * 120) % i === 0 && (h * 120) % i === 0) out.push(i / 120);
                return out.length ? out : [1];
            }
            function nearest(s) { return validScales.reduce((a, b) => Math.abs(b - s) < Math.abs(a - s) ? b : a); }
            readonly property var presets: {
                const seen = [];
                for (const want of [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]) {
                    const s = nearest(want);
                    if (!seen.some(x => Math.abs(x - s) < 0.001)) seen.push(s);
                }
                return seen;
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: scaleCol.presets
                    Link {
                        required property real modelData
                        text: +modelData.toFixed(2) + "×"
                    mono: true
                        primary: Math.abs((root.mon?.scale ?? 0) - modelData) < 0.005
                        onClicked: Displays.update(root.mon.name, { scale: modelData })
                    }
                }
            }
            Dial {
                width: parent.width
                ink: Theme.brassBright
                value: scaleCol.validScales.indexOf(scaleCol.nearest(root.mon?.scale ?? 1)) / Math.max(1, scaleCol.validScales.length - 1)
                onMoved: v => Displays.update(root.mon.name,
                    { scale: scaleCol.validScales[Math.round(v * (scaleCol.validScales.length - 1))] })
            }
        }

        Label { text: "rotation" }
        Flow {
            width: parent.width
            spacing: 6
            enabled: root.mon?.enabled ?? false
            Repeater {
                model: [{ t: 0, l: "normal" }, { t: 1, l: "90°" }, { t: 2, l: "180°" }, { t: 3, l: "270°" }]
                Link {
                    required property var modelData
                    text: modelData.l
                    mono: true
                    primary: root.mon?.transform === modelData.t
                    onClicked: Displays.update(root.mon.name, { transform: modelData.t })
                }
            }
        }

        Label { text: "brightness" }
        Dial {
            width: parent.width
            visible: root.ddcIndex(root.mon) >= 0
            ink: Theme.brassBright
            value: Brightness.displays[root.ddcIndex(root.mon)]?.value ?? 0
            onMoved: v => Brightness.set(root.ddcIndex(root.mon), v)
        }
        Text {
            visible: root.ddcIndex(root.mon) < 0
            width: parent.width
            wrapMode: Text.Wrap
            text: !Brightness.available ? "install ddcutil (and load i2c-dev) for brightness"
                : Brightness.scanning ? "looking for ddc/ci displays…" : "no ddc/ci brightness on this monitor"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }

    Text {
        visible: Displays.error !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: Displays.error
        color: Theme.signal
        font.family: Theme.fontData
        font.pixelSize: Theme.dataSizeSmall
    }

    // Apply / discard
    Item {
        visible: Displays.dirty && !Displays.confirming
        width: parent.width
        height: 30
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "unapplied changes"
            color: Theme.warn
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Row {
            anchors.right: parent.right
            spacing: 8
            Link { text: "discard"; onClicked: Displays.resetDraft() }
            Link { text: "apply"; primary: true; onClicked: Displays.apply() }
        }
    }

    component Label: Text {
        color: Theme.brass
        font.family: Theme.fontLabel
        font.pixelSize: Theme.labelSize
        font.capitalization: Font.SmallCaps
        font.letterSpacing: Theme.labelSpacing
        font.weight: Font.DemiBold
    }
}
