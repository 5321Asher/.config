import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../flyouts"

// The app buttons: your taskbar pins first (in order), then any other app with a window on this
// screen's desktop (or minimised). One button per app, as Windows groups them; a short grey pill
// under an app that's open, a longer accent one under the one you're in.
//   click         open it; its window: switch to it, or minimise it if it's the active one; several
//                 windows: the next one
//   right-click   the jump list: open another, pin / unpin, close
//   point at it   thumbnails of its windows (click one to switch; × to close it)
Row {
    id: root

    required property HyprlandMonitor monitor
    required property string screenName
    property real menuY: 0
    spacing: 4

    readonly property var windows: {
        const ws = monitor?.activeWorkspace?.id ?? -1;
        return Hyprland.toplevels.values.filter(t =>
            t.workspace?.id === ws || (Apps.isMin(t) && (t.monitor === monitor || !t.monitor)));
    }
    // [{ key, entry, wins }]
    readonly property var groups: {
        const out = [];
        const byKey = {};
        for (const e of Apps.taskbarEntries) { const g = { key: e.id, entry: e, wins: [] }; out.push(g); byKey[e.id] = g; }
        for (const t of windows) {
            const e = Apps.entryFor(t);
            const key = e?.id ?? ("app:" + Apps.appId(t));
            let g = byKey[key];
            if (!g) { g = { key: key, entry: e, wins: [] }; out.push(g); byKey[key] = g; }
            g.wins.push(t);
        }
        return out;
    }

    function click(g) {
        const wins = g.wins;
        if (wins.length === 0) { Apps.launch(g.entry); return; }
        if (wins.length === 1) {
            const t = wins[0];
            if (Apps.isMin(t)) Apps.restore(t, monitor?.activeWorkspace?.id);
            else if (t.activated) Apps.minimize(t);
            else Apps.focusWin(t);
            return;
        }
        // several: the one after the active one (restoring a minimised one)
        const i = wins.findIndex(t => t.activated);
        const next = wins[(i + 1) % wins.length];
        if (Apps.isMin(next)) Apps.restore(next, monitor?.activeWorkspace?.id);
        else Apps.focusWin(next);
    }

    function jumpList(g, item) {
        const e = g.entry;
        const name = e?.name ?? (g.wins[0]?.title ?? "App");
        const items = [];
        for (const a of (e?.actions ?? [])) items.push({ text: a.name, glyph: "", run: () => a.execute() });
        if (items.length) items.push({ sep: true });
        if (e) items.push({ text: name, icon: e.icon, run: () => Apps.launch(e) });
        if (e) items.push({ text: Apps.isPinned("taskbar", e) ? "Unpin from taskbar" : "Pin to taskbar", glyph: Apps.isPinned("taskbar", e) ? "" : "",
                            run: () => Apps.togglePin("taskbar", e) });
        if (g.wins.length) {
            const t = g.wins.find(w => w.activated) ?? g.wins[0];
            items.push({ sep: true });
            items.push({ text: "Minimize", glyph: "", enabled: !Apps.isMin(t), run: () => Apps.minimize(t) });
            items.push({ text: "Float / tile", glyph: "", run: () => Apps.onWindow(t, `hl.dsp.window.float({ action = "toggle" })`) });
            items.push({ text: g.wins.length > 1 ? "Close all windows" : "Close window", glyph: "",
                         run: () => g.wins.forEach((w, k) => closeLater(w, k)) });
        }
        const p = item.mapToItem(null, item.width / 2, 0);
        Flyouts.menu(screenName, items, p.x, menuY, true);
    }
    function closeLater(t, k) {
        const tm = Qt.createQmlObject("import QtQuick; Timer { interval: " + (k * 150 + 10) + " }", root);
        tm.triggered.connect(() => { Apps.closeWin(t); tm.destroy(); });
        tm.start();
    }

    // ---------------------------------------------------------------- the buttons
    Repeater {
        model: ScriptModel { values: root.groups; objectProp: "key" }
        Item {
            id: btn
            required property var modelData
            readonly property var g: modelData
            readonly property bool running: g.wins.length > 0
            readonly property bool current: g.wins.some(t => t.activated && !Apps.isMin(t))
            width: 44
            height: 40
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: mouse.pressed ? Theme.subtle2 : mouse.containsMouse || btn.current ? Qt.alpha(Theme.text, Theme.dark ? 0.08 : 0.055) : "transparent"
                border.width: mouse.containsMouse || btn.current ? 1 : 0
                border.color: Qt.alpha(Theme.text, Theme.dark ? 0.05 : 0.03)
            }
            AppIcon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                size: mouse.pressed ? 20 : Theme.taskIcon
                name: btn.g.entry?.icon || (btn.g.wins[0] ? Apps.iconFor(btn.g.wins[0]) : "")
                Behavior on size { NumberAnimation { duration: 80 } }
            }
            // the pill: grey while open, a longer accent one while active
            Rectangle {
                visible: btn.running
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                height: 3; radius: 1.5
                width: btn.current ? 16 : 6
                color: btn.current ? Theme.accent : Theme.text3
                Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    preview.shown = false;
                    if (e.button === Qt.RightButton) root.jumpList(btn.g, btn);
                    else if (e.button === Qt.MiddleButton) Apps.launch(btn.g.entry);
                    else root.click(btn.g);
                }
                onContainsMouseChanged: {
                    if (containsMouse) { leave.stop(); if (btn.running) hover.restart(); }
                    else { hover.stop(); leave.restart(); }
                }
            }
            Timer { id: hover; interval: 450; onTriggered: if (!Flyouts.isOpen) preview.shown = true }
            Timer { id: leave; interval: 250; onTriggered: if (!preview.inside) preview.shown = false }
            Tip { target: btn; hovered: mouse.containsMouse && !btn.running; text: btn.g.entry?.name ?? "" }

            // ------------------------------------------------ the thumbnails
            PopupWindow {
                id: preview
                property bool shown: false
                property bool inside: previewMouse.containsMouse
                onInsideChanged: if (!inside && !mouse.containsMouse) leave.restart()
                visible: shown && btn.running
                anchor.item: btn
                anchor.rect.x: Math.round(btn.width / 2 - implicitWidth / 2)
                anchor.rect.y: -implicitHeight - 10
                readonly property int thumbW: 200
                implicitWidth: btn.g.wins.length * (thumbW + 8) + 8
                implicitHeight: 166
                color: "transparent"

                Acrylic { anchors.fill: parent; shadow: false; tintAlpha: 0.97 }
                MouseArea { id: previewMouse; anchors.fill: parent; hoverEnabled: true }
                Row {
                    x: 8; y: 8
                    spacing: 8
                    Repeater {
                        model: preview.visible ? btn.g.wins : []
                        Item {
                            id: thumb
                            required property var modelData
                            width: preview.thumbW
                            height: 150
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radius
                                color: thumbMouse.containsMouse ? Theme.subtle : "transparent"
                            }
                            AppIcon { x: 8; y: 8; size: 16; name: Apps.iconFor(thumb.modelData) }
                            Txt { x: 32; y: 4; width: parent.width - 64; height: 24; text: thumb.modelData.title; size: Theme.caption }
                            ScreencopyView {
                                id: shot
                                x: 8; y: 34
                                width: parent.width - 16
                                height: parent.height - 42
                                captureSource: preview.visible && !Apps.isMin(thumb.modelData) ? thumb.modelData.wayland : null
                                live: true
                                constraintSize: Qt.size(width, height)
                            }
                            AppIcon { anchors.centerIn: shot; visible: !shot.hasContent; size: 40; name: Apps.iconFor(thumb.modelData) }
                            MouseArea {
                                id: thumbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    preview.shown = false;
                                    if (Apps.isMin(thumb.modelData)) Apps.restore(thumb.modelData, root.monitor?.activeWorkspace?.id);
                                    else Apps.focusWin(thumb.modelData);
                                }
                            }
                            Btn {
                                visible: thumbMouse.containsMouse || hovered
                                anchors.right: parent.right; anchors.rightMargin: 4
                                y: 4
                                width: 26; height: 26
                                kind: "subtle"
                                glyph: ""; glyphSize: 10
                                onClicked: { Apps.closeWin(thumb.modelData); }
                                Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.closeRed; visible: parent.hovered; z: -1 }
                                textColor: hovered ? "#ffffff" : Theme.text
                            }
                        }
                    }
                }
            }
        }
    }
}
