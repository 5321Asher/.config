import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"

// DISPLAY: the screens laid out (drag to move, edges snap), then the selected one's resolution,
// refresh, scale, rotation and brightness. Changes wait for apply; after it you have
// Displays.confirmSeconds to keep them or they revert. Profiles: named layouts.
Column {
    id: root

    spacing: 34
    Component.onCompleted: { Displays.refresh(); if (!Brightness.scanned) Brightness.scan(); }

    property string selected: Displays.draft[0]?.name ?? ""
    readonly property var mon: Displays.draft.find(m => m.name === selected) ?? Displays.draft[0] ?? null
    readonly property var enabledMonitors: Displays.draft.filter(m => m.enabled)
    function ddcIndex(m) {
        if (!m) return -1;
        return Brightness.displays.findIndex(d => d.name && (m.model.includes(d.name) || m.description.includes(d.name)));
    }

    // keep them?
    Item {
        visible: Displays.confirming
        width: parent.width
        height: 96
        Rectangle { anchors.fill: parent; radius: 28; color: Theme.s1; border { width: 1; color: Theme.red } }
        Lb { x: 24; y: 18; text: "keep these display settings?  reverting in " + Displays.countdown + " s"; color: Theme.fg }
        Row { x: 24; y: 42; spacing: 8
              Btn { text: "keep"; primary: true; onClicked: Displays.keep() }
              Btn { text: "revert"; onClicked: Displays.revert() } }
    }

    // display profiles: every screen's mode, position, scale, rotation under one name
    Section {
        title: "profiles"
        
        trailing: "click to load · auto by screens"
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: Displays.profiles
                Btn { required property var modelData; text: modelData.name; glyph: modelData.fits ? "\u{F0379}" : ""; on: modelData.active
                      onClicked: { profileName.text = modelData.name; Displays.applyProfile(modelData.id); } }
            }
            Label { visible: !Displays.profiles.length; text: "no profiles yet: name this layout and save it" }
        }
        Row {
            spacing: 8
            Field { id: profileName; width: 200; placeholder: "profile name"; onAccepted: Displays.saveProfile(text) }
            Btn { text: "save current"; primary: true; enabled: profileName.text.trim() !== ""; onClicked: Displays.saveProfile(profileName.text) }
            Btn { text: "delete"; visible: Displays.profiles.some(p => p.name === profileName.text.trim())
                  onClicked: { Displays.deleteProfile(Displays.profiles.find(p => p.name === profileName.text.trim()).id); profileName.text = ""; } }
        }
        Label { width: parent.width; wrapMode: Text.Wrap
                text: (Displays.profiles.find(p => p.active)?.summary ?? "") }
    }

    Section {
        title: "layout"
        
        trailing: "drag to move"
        Item {
            id: canvas
            width: parent.width
            height: 260
            readonly property var bounds: {
                const list = root.enabledMonitors.filter(m => !m.mirror);
                if (!list.length) return { x: 0, y: 0, w: 1, h: 1 };
                const xs = [], ys = [], xe = [], ye = [];
                for (const m of list) { const s = Displays.logical(m); xs.push(m.x); ys.push(m.y); xe.push(m.x + s.w); ye.push(m.y + s.h); }
                const x = Math.min(...xs), y = Math.min(...ys);
                return { x: x, y: y, w: Math.max(...xe) - x, h: Math.max(...ye) - y };
            }
            readonly property real k: Math.min((width - 40) / bounds.w, (height - 40) / bounds.h)
            readonly property real ox: (width - bounds.w * k) / 2
            readonly property real oy: (height - bounds.h * k) / 2

            Rectangle { anchors.fill: parent; radius: 28; color: Theme.s1; border { width: 1; color: Theme.s2 } }
            // a grid
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = Theme.alpha(Theme.fg, 0.07);
                    ctx.beginPath();
                    for (let x = 20; x < width; x += 20) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); }
                    for (let y = 20; y < height; y += 20) { ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); }
                    ctx.stroke();
                }
            }
            Repeater {
                model: root.enabledMonitors.filter(m => !m.mirror)
                Item {
                    id: box
                    required property var modelData
                    readonly property var size: Displays.logical(modelData)
                    readonly property bool sel: root.mon?.name === modelData.name
                    function place() {
                        x = Qt.binding(() => canvas.ox + (modelData.x - canvas.bounds.x) * canvas.k);
                        y = Qt.binding(() => canvas.oy + (modelData.y - canvas.bounds.y) * canvas.k);
                    }
                    Component.onCompleted: place()
                    width: size.w * canvas.k
                    height: size.h * canvas.k
                    z: dragArea.drag.active ? 10 : 1
                    Rectangle { anchors.fill: parent; radius: 14; color: box.sel ? Theme.fg : Theme.s2
                                border { width: 1; color: box.sel ? Theme.fg : Theme.s3 } }
                    Column {
                        anchors.centerIn: parent
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: box.modelData.name; px: 11; color: box.sel ? Theme.ink : Theme.fg }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: box.modelData.width + "×" + box.modelData.height; px: 10; color: box.sel ? Theme.ink : Theme.grey }
                    }
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        drag.target: box
                        drag.threshold: 4
                        cursorShape: Qt.OpenHandCursor
                        onPressed: root.selected = box.modelData.name
                        // commit when the drag ends: by `released`, drag.active is already false,
                        // so a check there threw every move away
                        drag.onActiveChanged: if (!drag.active) {
                            let nx = canvas.bounds.x + (box.x - canvas.ox) / canvas.k;
                            let ny = canvas.bounds.y + (box.y - canvas.oy) / canvas.k;
                            const snap = 20 / canvas.k, me = box.size;
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
        }
        Flow {
            width: parent.width
            spacing: 6
            Repeater { model: Displays.draft; Btn { required property var modelData; text: modelData.name; on: root.mon?.name === modelData.name
                                                    opacity: modelData.enabled ? 1 : 0.5; onClicked: root.selected = modelData.name } }
            Btn { visible: root.enabledMonitors.length > 1; text: Displays.mirrored ? "extend" : "mirror"
                  onClicked: Displays.setMirror(!Displays.mirrored, root.mon?.mirror || root.mon?.name) }
        }
    }

    Section {
        visible: !!root.mon
        title: root.mon ? root.mon.name : ""
        
        trailing: root.mon?.model ?? ""
        Row {
            spacing: 10
            Switch { checked: root.mon?.enabled ?? false; enabled: !(root.mon?.enabled && root.enabledMonitors.length === 1)
                     onToggled: Displays.update(root.mon.name, { enabled: !root.mon.enabled, mirror: "" }) }
            Label { anchors.verticalCenter: parent.verticalCenter; text: root.mon?.mirror ? "mirroring " + root.mon.mirror : root.mon?.enabled ? "enabled" : "off" }
        }
        Label { text: "resolution" }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: {
                    const seen = new Set();
                    return (root.mon?.modes ?? []).filter(m => { const k = m.width + "x" + m.height; if (seen.has(k)) return false; seen.add(k); return true; })
                        .sort((a, b) => b.width * b.height - a.width * a.height);
                }
                Btn {
                    required property var modelData
                    text: modelData.width + "×" + modelData.height
                    on: root.mon && root.mon.width === modelData.width && root.mon.height === modelData.height
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
            Repeater {
                model: (root.mon?.modes ?? []).filter(m => m.width === root.mon.width && m.height === root.mon.height).sort((a, b) => b.refresh - a.refresh)
                Btn { required property var modelData; text: modelData.refresh.toFixed(0) + " hz"
                      on: Math.abs((root.mon?.refresh ?? 0) - modelData.refresh) < 0.01
                      onClicked: Displays.update(root.mon.name, { refresh: modelData.refresh }) }
            }
        }
        Label { text: "scale  ·  " + (+(root.mon?.scale ?? 1).toFixed(2)) + "×" }
        Flow {
            width: parent.width
            spacing: 6
            readonly property var valid: {
                const w = root.mon?.width ?? 0, h = root.mon?.height ?? 0, out = [];
                for (let i = 30; i <= 360; i++) if ((w * 120) % i === 0 && (h * 120) % i === 0) out.push(i / 120);
                return out.length ? out : [1];
            }
            Repeater {
                model: {
                    const near = s => parent.valid.reduce((a, b) => Math.abs(b - s) < Math.abs(a - s) ? b : a, 1);
                    const out = [];
                    for (const want of [0.75, 1, 1.25, 1.5, 1.75, 2]) { const s = near(want); if (!out.some(x => Math.abs(x - s) < 0.001)) out.push(s); }
                    return out;
                }
                Btn { required property real modelData; text: +modelData.toFixed(2) + "×"; on: Math.abs((root.mon?.scale ?? 0) - modelData) < 0.005
                      onClicked: Displays.update(root.mon.name, { scale: modelData }) }
            }
        }
        Label { text: "rotation" }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: [{ t: 0, l: "0°" }, { t: 1, l: "90°" }, { t: 2, l: "180°" }, { t: 3, l: "270°" }]
                Btn { required property var modelData; text: modelData.l; on: root.mon?.transform === modelData.t
                      onClicked: Displays.update(root.mon.name, { transform: modelData.t }) }
            }
        }
        Label { text: "brightness" }
        Slider { visible: root.ddcIndex(root.mon) >= 0; width: parent.width; height: 48; glyph: "\u{F00E0}"
                 value: Brightness.displays[root.ddcIndex(root.mon)]?.value ?? 0; onMoved: v => Brightness.set(root.ddcIndex(root.mon), v) }
        Label { visible: root.ddcIndex(root.mon) < 0
                text: !Brightness.available ? "install ddcutil for brightness" : Brightness.scanning ? "looking for ddc/ci displays…" : "no ddc/ci on this screen" }
    }

    Label { visible: Displays.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Displays.error; color: Theme.red }
    Row {
        visible: Displays.dirty && !Displays.confirming
        spacing: 8
        Btn { text: "apply"; primary: true; onClicked: Displays.apply() }
        Btn { text: "discard"; onClicked: Displays.resetDraft() }
    }
}
