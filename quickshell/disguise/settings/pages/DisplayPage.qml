import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Display: the arrangement (drag the numbered screens; Identify), brightness (the laptop panel
// and DDC/CI monitors), then scale, resolution, orientation and refresh rate for the selected
// screen. Changes wait for "Apply" and ask "Keep these display settings?" (reverting in 15 s).
Column {
    id: root
    spacing: 4
    Component.onCompleted: { Displays.refresh(); if (!Brightness.scanned) Brightness.scan(); }

    property string selected: Displays.draft.find(m => m.focused)?.name ?? Displays.draft[0]?.name ?? ""
    readonly property var mon: Displays.draft.find(m => m.name === selected) ?? Displays.draft[0] ?? null
    readonly property var enabledMonitors: Displays.draft.filter(m => m.enabled)
    readonly property var resolutions: {
        const seen = new Set();
        return (mon?.modes ?? []).filter(m => { const k = m.width + "x" + m.height; if (seen.has(k)) return false; seen.add(k); return true; })
            .sort((a, b) => b.width * b.height - a.width * a.height);
    }
    readonly property var rates: (mon?.modes ?? []).filter(m => m.width === mon.width && m.height === mon.height).sort((a, b) => b.refresh - a.refresh)
    readonly property var scales: {
        const w = mon?.width ?? 0, h = mon?.height ?? 0;
        const ok = [];
        for (let i = 30; i <= 360; i++) if ((w * 120) % i === 0 && (h * 120) % i === 0) ok.push(i / 120);
        const near = s => ok.reduce((a, b) => Math.abs(b - s) < Math.abs(a - s) ? b : a, 1);
        const out = [];
        for (const want of [0.5, 0.6667, 0.75, 1, 1.25, 1.5, 1.75, 2, mon?.scale ?? 1]) { const s = near(want); if (!out.some(x => Math.abs(x - s) < 0.001)) out.push(s); }
        return out.sort((a, b) => a - b);
    }

    // ---------------------------------------------------------------- arrangement
    Card {
        id: arrange
        visible: Displays.draft.length > 0
        width: parent.width
        height: 220
        readonly property var list: root.enabledMonitors.filter(m => !m.mirror)
        readonly property var bounds: {
            if (!list.length) return { x: 0, y: 0, w: 1, h: 1 };
            const xs = [], ys = [], xe = [], ye = [];
            for (const m of list) { const s = Displays.logical(m); xs.push(m.x); ys.push(m.y); xe.push(m.x + s.w); ye.push(m.y + s.h); }
            const x = Math.min(...xs), y = Math.min(...ys);
            return { x: x, y: y, w: Math.max(...xe) - x, h: Math.max(...ye) - y };
        }
        readonly property real k: Math.min((width - 80) / bounds.w, (height - 90) / bounds.h)
        readonly property real ox: (width - bounds.w * k) / 2
        readonly property real oy: (height - 50 - bounds.h * k) / 2
        Repeater {
            model: arrange.list
            Item {
                id: box
                required property var modelData
                readonly property var size: Displays.logical(modelData)
                readonly property bool sel: root.mon?.name === modelData.name
                function place() {
                    x = Qt.binding(() => arrange.ox + (modelData.x - arrange.bounds.x) * arrange.k);
                    y = Qt.binding(() => arrange.oy + (modelData.y - arrange.bounds.y) * arrange.k);
                }
                Component.onCompleted: place()
                width: size.w * arrange.k
                height: size.h * arrange.k
                z: drag.drag.active ? 10 : 1
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.radius
                    color: box.sel ? Theme.accent : Theme.dark ? "#3a3a3a" : "#d6d6d6"
                    border.width: 1
                    border.color: Theme.controlStroke
                    Txt {
                        anchors.centerIn: parent
                        text: Displays.draft.findIndex(m => m.name === box.modelData.name) + 1
                        size: Math.min(parent.height * 0.5, 40)
                        color: box.sel ? Theme.accentText : Theme.text
                    }
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    drag.target: box
                    drag.threshold: 4
                    onPressed: root.selected = box.modelData.name
                    onReleased: {
                        if (!drag.active) return;
                        let nx = arrange.bounds.x + (box.x - arrange.ox) / arrange.k;
                        let ny = arrange.bounds.y + (box.y - arrange.oy) / arrange.k;
                        const snap = 20 / arrange.k, me = box.size;
                        let bx = null, by = null;
                        for (const o of root.enabledMonitors) {
                            if (o.name === box.modelData.name || o.mirror) continue;
                            const s = Displays.logical(o);
                            for (const c of [o.x + s.w, o.x - me.w, o.x, o.x + s.w - me.w])
                                if (Math.abs(nx - c) < snap && (bx === null || Math.abs(nx - c) < Math.abs(nx - bx))) bx = c;
                            for (const c of [o.y, o.y + s.h, o.y - me.h, o.y + s.h - me.h])
                                if (Math.abs(ny - c) < snap && (by === null || Math.abs(ny - c) < Math.abs(ny - by))) by = c;
                        }
                        Displays.update(box.modelData.name, { x: Math.round(bx ?? nx), y: Math.round(by ?? ny) });
                        box.place();
                    }
                }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            spacing: 8
            Txt { height: Theme.controlHeight; visible: Displays.dirty; text: "Select Apply to use the new layout"; level: 2; size: Theme.caption }
            Btn { text: "Revert"; enabled: Displays.dirty; onClicked: Displays.resetDraft() }
            Btn { kind: "accent"; text: "Apply"; enabled: Displays.dirty; onClicked: Displays.apply() }
        }
    }

    // ---------------------------------------------------------------- brightness
    Header { text: "Brightness & color" }
    SettingRow {
        visible: Backlight.available
        width: parent.width
        glyph: ""
        title: "Brightness"
        subtitle: "Adjust the brightness of the built-in display"
        Row {
            spacing: 8
            Slider { width: 220; anchors.verticalCenter: parent.verticalCenter; value: Backlight.value; onMoved: v => Backlight.set(v) }
            Txt { width: 40; height: 32; text: Math.round(Backlight.value * 100) }
        }
    }
    Repeater {
        model: Brightness.displays
        SettingRow {
            required property var modelData
            required property int index
            width: root.width
            glyph: ""
            title: "Brightness · " + (modelData.name || "Monitor " + (index + 1))
            subtitle: "Over DDC/CI"
            Row {
                spacing: 8
                Slider { width: 220; anchors.verticalCenter: parent.verticalCenter; value: modelData.value; onMoved: v => Brightness.set(index, v) }
                Txt { width: 40; height: 32; text: Math.round(modelData.value * 100) }
            }
        }
    }
    SettingRow {
        visible: !Backlight.available && Brightness.displays.length === 0
        width: parent.width
        glyph: ""
        title: "Brightness"
        subtitle: Brightness.scanning ? "Looking for monitors…" : !Brightness.available ? "Install ddcutil (and load i2c-dev) to set your monitors' brightness" : "None of your monitors take brightness over DDC/CI"
        Btn { text: "Look again"; enabled: !Brightness.scanning; onClicked: Brightness.scan() }
    }

    // ---------------------------------------------------------------- scale & layout
    Header { text: "Scale & layout" + (Displays.draft.length > 1 ? " · Display " + (Displays.draft.findIndex(m => m.name === root.selected) + 1) : "") }
    SettingRow {
        visible: Displays.draft.length > 1
        width: parent.width
        glyph: ""; title: "Display"; subtitle: "Choose which screen these settings change"
        Combo {
            width: 260
            model: Displays.draft
            textOf: m => (Displays.draft.indexOf(m) + 1) + ". " + m.name + (m.model ? " (" + m.model + ")" : "")
            currentIndex: Displays.draft.findIndex(m => m.name === root.selected)
            onChosen: i => root.selected = Displays.draft[i].name
        }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Scale"; subtitle: "Change the size of text, apps, and other items"
        Combo {
            width: 200
            model: root.scales
            textOf: s => Math.round(s * 100) + "%" + (Math.abs(s - 1) < 0.001 ? " (Recommended)" : "")
            currentIndex: root.scales.findIndex(s => Math.abs(s - (root.mon?.scale ?? 1)) < 0.005)
            onChosen: i => Displays.update(root.mon.name, { scale: root.scales[i] })
        }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Display resolution"; subtitle: "Adjust the resolution to fit your connected display"
        Combo {
            width: 200
            model: root.resolutions
            textOf: m => m.width + " × " + m.height + (m === root.resolutions[0] ? " (Recommended)" : "")
            currentIndex: root.resolutions.findIndex(m => m.width === root.mon?.width && m.height === root.mon?.height)
            onChosen: i => {
                const m = root.resolutions[i];
                const rates = root.mon.modes.filter(x => x.width === m.width && x.height === m.height).map(x => x.refresh);
                Displays.update(root.mon.name, { width: m.width, height: m.height, refresh: Math.max(...rates) });
            }
        }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Display orientation"
        Combo {
            width: 200
            model: ["Landscape", "Portrait", "Landscape (flipped)", "Portrait (flipped)"]
            currentIndex: [0, 1, 2, 3].indexOf(root.mon?.transform ?? 0)
            onChosen: i => Displays.update(root.mon.name, { transform: i })
        }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Choose a refresh rate"; subtitle: "A higher rate gives smoother motion"
        Combo {
            width: 200
            model: root.rates
            textOf: m => m.refresh.toFixed(2).replace(/\.?0+$/, "") + " Hz"
            currentIndex: root.rates.findIndex(m => Math.abs(m.refresh - (root.mon?.refresh ?? 0)) < 0.01)
            onChosen: i => Displays.update(root.mon.name, { refresh: root.rates[i].refresh })
        }
    }
    SettingRow {
        visible: Displays.draft.length > 1
        width: parent.width
        glyph: ""; title: "Use this display"; subtitle: "Turn it off to extend onto the others only"
        Toggle {
            checked: root.mon?.enabled ?? false
            enabled: !(root.mon?.enabled && root.enabledMonitors.length === 1)
            onToggled: Displays.update(root.mon.name, { enabled: !root.mon.enabled, mirror: "" })
        }
    }
    SettingRow {
        visible: root.enabledMonitors.length > 1 || Displays.mirrored
        width: parent.width
        glyph: ""; title: "Duplicate these displays"
        Toggle { checked: !!root.mon?.mirror; onToggled: Displays.setMirror(!root.mon?.mirror, root.mon?.mirror || root.mon?.name) }
    }
    Txt { visible: Displays.error !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Displays.error }

    // "Keep these display settings?"
    Connections {
        target: Displays
        function onConfirmingChanged() { keep.visible = Displays.confirming; }
    }
    Card {
        id: keep
        visible: false
        width: parent.width
        height: 120
        color: Theme.accentMuted
        Column {
            x: 20; y: 16
            spacing: 4
            Txt { text: "Keep these display settings?"; strong: true; size: Theme.bodyLarge }
            Txt { text: "Reverting to previous display settings in " + Displays.countdown + " seconds."; level: 2 }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 20
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
            spacing: 8
            Btn { kind: "accent"; text: "Keep changes"; onClicked: Displays.keep() }
            Btn { text: "Revert"; onClicked: Displays.revert() }
        }
    }
}
