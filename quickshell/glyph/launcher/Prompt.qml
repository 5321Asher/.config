import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// A question from ~/.config/theme/prompt (the web-app and keybind scripts): the question as a label,
// the answer pill with the red caret, and the choices (when it offers some) as pill rows, the picked
// one white. Type to filter, ↑↓ pick, Enter answers, Esc cancels. State: PromptState.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    readonly property real s: Theme.scaleFor(screen)

    property real t: PromptState.open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PromptState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-prompt"

    readonly property var req: PromptState.request
    readonly property bool choosing: (req.options ?? []).length > 0
    property int sel: 0
    readonly property var filtered: {
        const opts = (req.options ?? []).map((t, i) => ({ text: t, i: i }));
        const q = field.text.trim().toLowerCase();
        if (q === "" || req.input) return opts;
        const words = q.split(/\s+/);
        return opts.filter(o => words.every(w => o.text.toLowerCase().includes(w)));
    }
    onFilteredChanged: sel = 0

    function submit() {
        if (choosing && !req.input && filtered.length > 0) {
            const o = filtered[Math.min(sel, filtered.length - 1)];
            PromptState.answer(req.index ? String(o.i) : o.text);
        } else if (choosing && req.input && field.text === "" && filtered.length > 0) {
            const o = filtered[Math.min(sel, filtered.length - 1)];
            PromptState.answer(req.index ? String(o.i) : o.text);
        } else if (req.index) PromptState.answer("");
        else PromptState.answer(field.text);
    }
    function step(d) {
        const n = filtered.length;
        if (n > 0) sel = (sel + d + n) % n;
    }

    Connections {
        target: PromptState
        function onDirChanged() { if (PromptState.open) { field.text = ""; root.sel = 0; field.focusField(); } }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: PromptState.cancel() }
    }

    Stage {
        id: stage
        s: root.s

        Rectangle {
            id: panel
            width: Math.min(860, stage.width - 120)
            height: 30 + 40 + 66 + (root.choosing ? Math.min(list.contentHeight, 72 * 7) + 24 : 0) + 34
            x: (stage.width - width) / 2
            y: Math.max(100, stage.height * 0.28) + 24 * (1 - root.t)
            opacity: root.t
            radius: 44
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            MouseArea { anchors.fill: parent }

            Row {
                x: 40
                y: 30
                spacing: 14
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: Theme.red }
                Lb { anchors.verticalCenter: parent.verticalCenter; text: "input required"; color: Theme.fg }
            }
            Field {
                id: field
                x: 34
                y: 70
                width: parent.width - 68
                height: 66
                glyph: "\u{F0349}"
                placeholder: root.req.placeholder || (root.choosing ? "Choose" : "Type the answer")
                password: !!root.req.password
                onAccepted: root.submit()
                onKeyPressed: e => {
                    if (e.key === Qt.Key_Escape) PromptState.cancel();
                    else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) root.step(1);
                    else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) root.step(-1);
                    else return;
                    e.accepted = true;
                }
            }
            ListView {
                id: list
                visible: root.choosing
                x: 34
                y: field.y + field.height + 24
                width: parent.width - 68
                height: Math.min(contentHeight, 72 * 7)
                clip: true
                model: root.filtered.length
                currentIndex: root.sel
                spacing: 6
                highlightMoveDuration: Theme.fast
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: row
                    required property int index
                    readonly property var it: root.filtered[index] ?? ({ text: "" })
                    readonly property bool on: index === root.sel
                    width: list.width
                    height: 66
                    Rectangle { anchors.fill: parent; radius: 33; color: row.on ? Theme.fg : hov.hovered ? Theme.s2 : "transparent" }
                    Text {
                        x: 28
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 120
                        elide: Text.ElideRight
                        text: row.it.text
                        font { family: Theme.ui; pixelSize: 17 }
                        color: row.on ? Theme.ink : Theme.fg
                    }
                    Num {
                        anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                        text: String(row.it.i + 1).padStart(2, "0")
                        font.pixelSize: 28
                        color: row.on ? Theme.ink : Theme.s3
                    }
                    HoverHandler { id: hov }
                    TapHandler { onTapped: { root.sel = row.index; root.submit(); } }
                }
            }
        }

        Row {
            anchors { horizontalCenter: parent.horizontalCenter; top: panel.bottom; topMargin: 34 }
            opacity: root.t
            spacing: 34
            Lb { visible: root.choosing; text: "↑↓ choose" }
            Lb { text: "↵ answer" }
            Lb { text: "esc cancel" }
        }
    }
}
