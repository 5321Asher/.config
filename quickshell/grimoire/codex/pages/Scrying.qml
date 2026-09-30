import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"

// VIII. Scrying: the screens laid out on the page (drag to move them, edges snap), then the chosen
// one's resolution, refresh, scale, turning and light. Changes wait for "apply" (a bar at the top of the
// page and a row at its foot, whenever something is changed); after it you have
// Displays.confirmSeconds to keep them or they revert.
Column {
    id: root

    spacing: 22
    Component.onCompleted: { Displays.refresh(); if (!Brightness.scanned) Brightness.scan(); }

    property string selected: Displays.draft[0]?.name ?? ""
    readonly property var mon: Displays.draft.find(m => m.name === selected) ?? Displays.draft[0] ?? null
    readonly property var enabledMonitors: Displays.draft.filter(m => m.enabled)
    // a laptop's own panel: its light is the backlight
    function backlit(m) { return !!m && Backlight.available && /^(eDP|LVDS|DSI)/.test(m.name); }
    function ddcIndex(m) {
        if (!m) return -1;
        return Brightness.displays.findIndex(d => d.name && (m.model.includes(d.name) || m.description.includes(d.name)));
    }

    // changes waiting: apply them (also at the foot of the page)
    Item {
        visible: Displays.dirty && !Displays.confirming
        width: parent.width
        height: 70
        Rectangle { anchors.fill: parent; radius: 3; color: Theme.alpha(Theme.gold, 0.14); border.width: 1; border.color: Theme.alpha(Theme.goldDeep, 0.8) }
        Body { x: 14; y: 10; text: "The screens are changed on the page, not yet in the world."; strong: true }
        Row { x: 14; y: 36; spacing: 8
              Btn { text: "apply"; primary: true; onClicked: Displays.apply() }
              Btn { text: "never mind"; onClicked: Displays.resetDraft() } }
    }

    // keep them?
    Item {
        visible: Displays.confirming
        width: parent.width
        height: 70
        Rectangle { anchors.fill: parent; radius: 3; color: Theme.alpha(Theme.rubric, 0.1); border.width: 1; border.color: Theme.rubric }
        Body { x: 14; y: 10; text: "Keep what you see? It reverts in " + Displays.countdown + " s."; strong: true }
        Row { x: 14; y: 36; spacing: 8
              Btn { text: "keep"; primary: true; onClicked: Displays.keep() }
              Btn { text: "revert"; onClicked: Displays.revert() } }
    }

    Section {
        title: "the screens"
        trailing: "drag to move them"
        Item {
            id: canvas
            width: parent.width
            height: 200
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

            Rectangle { anchors.fill: parent; radius: 3; color: Theme.alpha(Theme.ink, 0.06); border.width: 1; border.color: Theme.alpha(Theme.inkDim, 0.4) }
            // a grid
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = Theme.alpha(Theme.inkDim, 0.12);
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
                    Rectangle { anchors.fill: parent; radius: 2; color: box.sel ? Theme.alpha(Theme.gold, 0.35) : Theme.alpha(Theme.page, 0.9)
                                border.width: box.sel ? 2 : 1; border.color: box.sel ? Theme.goldDeep : Theme.inkDim }
                    Column {
                        anchors.centerIn: parent
                        Body { anchors.horizontalCenter: parent.horizontalCenter; text: box.modelData.name; strong: true }
                        Body { anchors.horizontalCenter: parent.horizontalCenter; text: box.modelData.width + "×" + box.modelData.height; italic: true; color: Theme.inkDim; font.pixelSize: 12 }
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
            Seal { checked: root.mon?.enabled ?? false; enabled: !(root.mon?.enabled && root.enabledMonitors.length === 1)
                     onToggled: Displays.update(root.mon.name, { enabled: !root.mon.enabled, mirror: "" }) }
            Body { anchors.verticalCenter: parent.verticalCenter; italic: true; text: root.mon?.mirror ? "a mirror of " + root.mon.mirror : root.mon?.enabled ? "awake" : "dark" }
        }
        Caps { text: "resolution" }
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
        Caps { text: "refresh" }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: (root.mon?.modes ?? []).filter(m => m.width === root.mon.width && m.height === root.mon.height).sort((a, b) => b.refresh - a.refresh)
                Btn { required property var modelData; text: modelData.refresh.toFixed(0) + " Hz"
                      on: Math.abs((root.mon?.refresh ?? 0) - modelData.refresh) < 0.01
                      onClicked: Displays.update(root.mon.name, { refresh: modelData.refresh }) }
            }
        }
        Caps { text: "scale · " + (+(root.mon?.scale ?? 1).toFixed(2)) + "×" }
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
        Caps { text: "turning" }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: [{ t: 0, l: "upright" }, { t: 1, l: "a quarter" }, { t: 2, l: "upside down" }, { t: 3, l: "three quarters" }]
                Btn { required property var modelData; text: modelData.l; on: root.mon?.transform === modelData.t
                      onClicked: Displays.update(root.mon.name, { transform: modelData.t }) }
            }
        }
        Caps { text: "light" }
        Slider { visible: root.backlit(root.mon); width: parent.width; color: Theme.warn; value: Backlight.value; onMoved: v => Backlight.set(v) }
        Slider { visible: root.ddcIndex(root.mon) >= 0; width: parent.width; color: Theme.warn
                 value: Brightness.displays[root.ddcIndex(root.mon)]?.value ?? 0; onMoved: v => Brightness.set(root.ddcIndex(root.mon), v) }
        Body { visible: root.ddcIndex(root.mon) < 0 && !root.backlit(root.mon); italic: true; color: Theme.inkDim
                text: !Brightness.available ? "install ddcutil for brightness" : Brightness.scanning ? "looking for ddc/ci displays…" : "no ddc/ci on this screen" }
    }

    Body { visible: Displays.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Displays.error; color: Theme.danger; italic: true }
    Row {
        visible: Displays.dirty && !Displays.confirming
        spacing: 8
        Btn { text: "apply"; primary: true; onClicked: Displays.apply() }
        Btn { text: "never mind"; onClicked: Displays.resetDraft() }
    }
}
