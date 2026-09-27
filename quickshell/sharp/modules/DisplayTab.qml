import QtQuick
import QtQuick.Layouts

// Display settings: drag-to-arrange layout, mirror/extend, resolution, refresh, scale, rotation, brightness
Flickable {
    id: root

    property string selected: ""
    readonly property var mon: Displays.draft.find(m => m.name === selected) ?? Displays.draft[0] ?? null
    readonly property var enabledMonitors: Displays.draft.filter(m => m.enabled)

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    // ddcutil display matching this monitor's model, if any
    function ddcIndex(m) {
        if (!m)
            return -1;
        return Brightness.displays.findIndex(d => d.name && (m.model.includes(d.name) || m.description.includes(d.name)));
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    onVisibleChanged: if (visible) {
        Displays.refresh();
        if (!Brightness.scanned)
            Brightness.scan();
    }

    ColumnLayout {
        id: content

        width: root.width
        spacing: 10

        // Pending confirmation
        Rectangle {
            Layout.fillWidth: true
            visible: Displays.confirming
            implicitHeight: confirmCol.implicitHeight + 24
            radius: 0
            color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.12)
            border.width: 1
            border.color: Theme.warn

            ColumnLayout {
                id: confirmCol

                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Keep these display settings? Reverting in " + Displays.countdown + "s"
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.warn
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item { Layout.fillWidth: true }

                    IconButton {
                        label: "Revert"
                        onClicked: Displays.revert()
                    }

                    IconButton {
                        primary: true
                        label: "Keep"
                        onClicked: Displays.keep()
                    }
                }
            }
        }

        // Layout editor
        Card {
            title: "Arrangement"
            trailing: "drag to move"
            trailingColor: Theme.border

            Rectangle {
                id: canvas

                // Fit every enabled monitor's logical rect into the canvas
                readonly property var bounds: {
                    const list = root.enabledMonitors.filter(m => !m.mirror);
                    if (!list.length)
                        return { x: 0, y: 0, w: 1, h: 1 };
                    const xs = [], ys = [], xe = [], ye = [];
                    for (const m of list) {
                        const s = Displays.logical(m);
                        xs.push(m.x); ys.push(m.y); xe.push(m.x + s.w); ye.push(m.y + s.h);
                    }
                    const x = Math.min(...xs), y = Math.min(...ys);
                    return { x: x, y: y, w: Math.max(...xe) - x, h: Math.max(...ye) - y };
                }
                readonly property real pad: 20
                readonly property real k: Math.min((width - pad * 2) / bounds.w, (height - pad * 2) / bounds.h)
                readonly property real ox: (width - bounds.w * k) / 2
                readonly property real oy: (height - bounds.h * k) / 2

                Layout.fillWidth: true
                implicitHeight: 210
                radius: 0
                color: Theme.bg

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
                        radius: 0
                        color: isSelected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) : Theme.surface
                        border.width: 2
                        border.color: isSelected ? Theme.accent : dragArea.containsMouse ? Theme.accentMuted : Theme.hover
                        z: dragArea.drag.active ? 10 : 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: box.modelData.name
                                font.family: Theme.font
                                font.pixelSize: 11
                                font.bold: true
                                color: box.isSelected ? Theme.accent : Theme.fg
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: box.modelData.width + "×" + box.modelData.height
                                font.family: Theme.font
                                font.pixelSize: 9
                                color: Theme.dim
                            }

                            // Mirrors shown on their source
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: text !== ""
                                text: Displays.draft.filter(m => m.mirror === box.modelData.name).map(m => "+ " + m.name).join(" ")
                                font.family: Theme.font
                                font.pixelSize: 9
                                color: Theme.purple
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
                            onReleased: {
                                if (!drag.active)
                                    return;
                                // Back to layout coordinates, then snap to other monitors' edges
                                let nx = canvas.bounds.x + (box.x - canvas.ox) / canvas.k;
                                let ny = canvas.bounds.y + (box.y - canvas.oy) / canvas.k;
                                // Snap within 20 on-screen pixels
                                const snap = 20 / canvas.k;
                                const me = box.size;
                                let bestX = null, bestY = null;
                                for (const o of root.enabledMonitors) {
                                    if (o.name === box.modelData.name || o.mirror)
                                        continue;
                                    const s = Displays.logical(o);
                                    for (const c of [o.x + s.w, o.x - me.w, o.x, o.x + s.w - me.w])
                                        if (Math.abs(nx - c) < snap && (bestX === null || Math.abs(nx - c) < Math.abs(nx - bestX)))
                                            bestX = c;
                                    for (const c of [o.y, o.y + s.h, o.y - me.h, o.y + s.h - me.h])
                                        if (Math.abs(ny - c) < snap && (bestY === null || Math.abs(ny - c) < Math.abs(ny - bestY)))
                                            bestY = c;
                                }
                                Displays.update(box.modelData.name, {
                                    x: Math.round(bestX ?? nx),
                                    y: Math.round(bestY ?? ny)
                                });
                                // Dragging replaced the position bindings; follow the draft again
                                box.place();
                            }
                        }
                    }
                }
            }

            // Extend / mirror
            RowLayout {
                Layout.fillWidth: true
                visible: root.enabledMonitors.length > 1
                spacing: 6

                IconButton {
                    Layout.fillWidth: true
                    icon: root.glyph(0xF0379)
                    label: "Extend"
                    primary: !Displays.mirrored
                    onClicked: Displays.setMirror(false)
                }

                IconButton {
                    Layout.fillWidth: true
                    icon: root.glyph(0xF01AB)
                    label: "Mirror " + (root.mon?.name ?? "")
                    primary: Displays.mirrored
                    onClicked: Displays.setMirror(true, root.mon?.mirror || root.mon?.name)
                }
            }
        }

        // Monitor picker
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Displays.draft

                IconButton {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: root.glyph(0xF0379)
                    label: modelData.name
                    primary: root.mon?.name === modelData.name
                    tint: modelData.enabled ? Theme.fg : Theme.border
                    onClicked: root.selected = modelData.name
                }
            }
        }

        // Selected monitor
        Card {
            visible: !!root.mon
            title: root.mon ? root.mon.name + "  ·  " + root.mon.model : ""
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: root.mon?.mirror ? "Mirroring " + root.mon.mirror : "Enabled"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.fg
                }

                Switch {
                    checked: root.mon?.enabled ?? false
                    // Never allow turning off the last screen
                    enabled: !(root.mon?.enabled && root.enabledMonitors.length === 1)
                    onToggled: Displays.update(root.mon.name, { enabled: !root.mon.enabled, mirror: "" })
                }
            }

            Label { text: "Resolution" }

            Dropdown {
                enabled: root.mon?.enabled ?? false
                options: {
                    const seen = new Set();
                    return (root.mon?.modes ?? [])
                        .filter(m => { const k = m.width + "x" + m.height; if (seen.has(k)) return false; seen.add(k); return true; })
                        .sort((a, b) => b.width * b.height - a.width * a.height)
                        .map(m => ({ label: m.width + " × " + m.height, value: m.width + "x" + m.height }));
                }
                value: root.mon ? root.mon.width + "x" + root.mon.height : ""
                onPicked: v => {
                    const [w, h] = v.split("x").map(Number);
                    const rates = root.mon.modes.filter(m => m.width === w && m.height === h).map(m => m.refresh);
                    Displays.update(root.mon.name, { width: w, height: h, refresh: Math.max(...rates) });
                }
            }

            Label { text: "Refresh rate" }

            Dropdown {
                enabled: root.mon?.enabled ?? false
                options: (root.mon?.modes ?? [])
                    .filter(m => m.width === root.mon.width && m.height === root.mon.height)
                    .sort((a, b) => b.refresh - a.refresh)
                    .map(m => ({ label: m.refresh.toFixed(2) + " Hz", value: m.refresh }))
                value: root.mon?.refresh
                onPicked: v => Displays.update(root.mon.name, { refresh: v })
            }

            Label { text: "Scale" }

            ColumnLayout {
                id: scaleCol

                // Hyprland only accepts scales that are multiples of 1/120 AND give a whole-pixel logical size
                // on both axes; anything else gets replaced by the nearest valid one. So offer only those.
                // (e.g. 1366x768 can't do 0.75: 1366 / 0.75 = 1821.33)
                readonly property var validScales: {
                    const w = root.mon?.width ?? 0, h = root.mon?.height ?? 0;
                    const out = [];
                    for (let i = 30; i <= 360; i++)  // 0.25x … 3x
                        if ((w * 120) % i === 0 && (h * 120) % i === 0)
                            out.push(i / 120);
                    return out.length ? out : [1];
                }
                // Common choices, snapped to the nearest valid scale
                readonly property var presets: {
                    const seen = [];
                    for (const want of [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]) {
                        const s = nearest(want);
                        if (!seen.some(x => Math.abs(x - s) < 0.001))
                            seen.push(s);
                    }
                    return seen;
                }

                function nearest(s) {
                    return validScales.reduce((a, b) => Math.abs(b - s) < Math.abs(a - s) ? b : a);
                }
                function indexOf(s) {
                    return validScales.indexOf(nearest(s));
                }
                function setScale(s) {
                    Displays.update(root.mon.name, { scale: nearest(s) });
                }
                function step(d) {
                    const i = Math.max(0, Math.min(validScales.length - 1, indexOf(root.mon.scale) + d));
                    Displays.update(root.mon.name, { scale: validScales[i] });
                }
                function label(s) {
                    return +s.toFixed(2) + "×";
                }

                Layout.fillWidth: true
                spacing: 8

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: scaleCol.presets

                        IconButton {
                            required property real modelData
                            label: scaleCol.label(modelData)
                            primary: Math.abs((root.mon?.scale ?? 0) - modelData) < 0.005
                            enabled: root.mon?.enabled ?? false
                            onClicked: scaleCol.setScale(modelData)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    enabled: root.mon?.enabled ?? false
                    opacity: enabled ? 1 : 0.4

                    IconButton {
                        label: "−"
                        onClicked: scaleCol.step(-1)
                    }

                    // Moves through the valid scales only
                    Slider {
                        Layout.fillWidth: true
                        step: 1 / Math.max(1, scaleCol.validScales.length - 1)
                        value: scaleCol.indexOf(root.mon?.scale ?? 1) / Math.max(1, scaleCol.validScales.length - 1)
                        onMoved: v => Displays.update(root.mon.name,
                            { scale: scaleCol.validScales[Math.round(v * (scaleCol.validScales.length - 1))] })
                    }

                    IconButton {
                        label: "+"
                        onClicked: scaleCol.step(1)
                    }

                    Text {
                        Layout.minimumWidth: 40
                        horizontalAlignment: Text.AlignRight
                        text: scaleCol.label(root.mon?.scale ?? 1)
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.fg
                    }
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: `Only scales that divide ${root.mon?.width ?? 0}×${root.mon?.height ?? 0} into whole pixels work`
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }

            Label { text: "Rotation" }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [{ t: 0, l: "Normal" }, { t: 1, l: "90°" }, { t: 2, l: "180°" }, { t: 3, l: "270°" }]

                    IconButton {
                        required property var modelData
                        label: modelData.l
                        primary: root.mon?.transform === modelData.t
                        enabled: root.mon?.enabled ?? false
                        onClicked: Displays.update(root.mon.name, { transform: modelData.t })
                    }
                }
            }

            Label { text: "Brightness" }

            Slider {
                Layout.fillWidth: true
                visible: root.ddcIndex(root.mon) >= 0
                value: Brightness.displays[root.ddcIndex(root.mon)]?.value ?? 0
                onMoved: v => Brightness.set(root.ddcIndex(root.mon), v)
            }

            Text {
                Layout.fillWidth: true
                visible: root.ddcIndex(root.mon) < 0
                text: !Brightness.available ? "Install ddcutil (and load i2c-dev) to control brightness"
                    : Brightness.scanning ? "Looking for DDC/CI displays…"
                    : "This monitor doesn't support DDC/CI brightness"
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Displays.error !== ""
            text: Displays.error
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.danger
        }

        // Apply / discard
        RowLayout {
            Layout.fillWidth: true
            visible: Displays.dirty && !Displays.confirming
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: "Unapplied changes"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }

            IconButton {
                label: "Discard"
                onClicked: Displays.resetDraft()
            }

            IconButton {
                primary: true
                label: "Apply"
                onClicked: Displays.apply()
            }
        }
    }

    component Label: Text {
        font.family: Theme.font
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: Theme.dim
    }
}
