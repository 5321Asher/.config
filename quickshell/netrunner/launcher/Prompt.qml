import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// INPUT REQUIRED 入力: Netrunner's answer to `walker --dmenu`, for the questions the web-app and
// keybind scripts ask through ~/.config/theme/prompt (PromptState). A cut-corner terminal with the
// question, an entry line and, when there are choices, an address list to pick from. Type to
// filter, ↑ ↓ / Tab choose, Enter answers, Esc cancels. No match: Enter answers with what you typed.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: PromptState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-prompt"
    WlrLayershell.keyboardFocus: PromptState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shown: PromptState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    readonly property var req: PromptState.request
    readonly property bool choosing: !req.input && (req.options ?? []).length > 0
    property string query: ""
    property int sel: 0
    property point pointer: Qt.point(-1, -1)

    readonly property var filtered: {
        const opts = (req.options ?? []).map((t, i) => ({ text: t, i: i }));
        const q = query.trim().toLowerCase();
        if (q === "") return opts;
        const words = q.split(/\s+/);
        return opts.filter(o => words.every(w => o.text.toLowerCase().includes(w)));
    }
    onQueryChanged: sel = 0

    function submit() {
        if (choosing && filtered.length > 0) {
            const o = filtered[Math.min(sel, filtered.length - 1)];
            PromptState.answer(req.index ? String(o.i) : o.text);
        } else if (req.index) PromptState.answer("");
        else PromptState.answer(query);
    }
    function step(d) {
        const n = filtered.length;
        if (n > 0) sel = (sel + d + n) % n;
    }

    Connections {
        target: PromptState
        function onDirChanged() { if (PromptState.open) { root.query = ""; root.sel = 0; field.focusField(); title.replay(); } }
    }

    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.6 * root.shown) }
    MouseArea { anchors.fill: parent; onClicked: PromptState.cancel() }

    Item {
        id: box
        width: Math.min(760, root.width - 64)
        height: 132 + (root.choosing ? Math.max(30, Math.min(list.contentHeight, 44 * 9)) + 12 : 0)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.22)
        opacity: root.shown
        transform: Translate { y: (1 - root.shown) * -16 }
        MouseArea { anchors.fill: parent }

        Chamfer { anchors.fill: parent; cut: 18; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.95); stroke: Theme.alpha(Theme.yellow, 0.7) }
        Hazard { x: parent.width - 120; y: parent.height - 6; width: 90; height: 6 }

        Row {
            x: 18; y: 16
            spacing: 10
            Tag { anchors.verticalCenter: parent.verticalCenter; text: "INPUT REQUIRED"; height: 22; color: Theme.yellow }
            Jp { anchors.verticalCenter: parent.verticalCenter; text: "入力" }
        }
        Scramble {
            id: title
            x: 18; y: 50
            width: parent.width - 36
            elide: Text.ElideRight
            target: (root.req.placeholder || "enter value").toUpperCase()
            color: Theme.bright
            font.family: Theme.condensed; font.pixelSize: 22; font.weight: Font.DemiBold; font.letterSpacing: 1
        }
        Field {
            id: field
            x: 18; y: 84
            width: parent.width - 36
            height: 36
            text: root.query
            placeholder: root.choosing ? "type to filter  //  ↑↓ choose  //  enter answers  //  esc cancels" : "type  //  enter answers  //  esc cancels"
            onEdited: root.query = text
            onAccepted: root.submit()
            input.font.pixelSize: 16
            input.Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { PromptState.cancel(); e.accepted = true; }
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { root.step(1); e.accepted = true; }
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { root.step(-1); e.accepted = true; }
            }
        }
        ListView {
            id: list
            visible: root.choosing
            x: 18; y: 132
            width: parent.width - 36
            height: Math.min(contentHeight, 44 * 9)
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.choosing ? root.filtered : []
            currentIndex: root.sel
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === root.sel
                width: list.width
                height: 40
                Chamfer {
                    anchors.fill: parent
                    cut: 8; corners: "tr bl"
                    fill: row.sel ? Theme.alpha(Theme.yellow, 0.16) : Theme.alpha(Theme.bg, 0.6)
                    stroke: row.sel ? Theme.yellow : Theme.alpha(Theme.line, 0.9)
                }
                Text {
                    x: 12; anchors.verticalCenter: parent.verticalCenter
                    text: "0x" + row.modelData.i.toString(16).toUpperCase().padStart(2, "0")
                    color: row.sel ? Theme.yellow : Theme.dim
                    font.family: Theme.mono; font.pixelSize: Theme.label
                }
                Text {
                    x: 60; width: parent.width - 72
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.text
                    color: row.sel ? Theme.bright : Theme.fg
                    font.family: Theme.sans; font.pixelSize: Theme.data + 1
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPositionChanged: m => { const p = mapToGlobal(m.x, m.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.sel = row.index; } }
                    onClicked: { root.sel = row.index; root.submit(); }
                }
            }
        }
        Label {
            visible: root.choosing && root.filtered.length === 0
            x: 18; y: 140
            text: root.req.index ? "NO MATCH" : "NO MATCH  //  ENTER ANSWERS WITH WHAT YOU TYPED"
        }
    }
}
