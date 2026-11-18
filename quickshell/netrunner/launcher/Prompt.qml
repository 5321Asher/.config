import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// INPUT REQUIRED 入力: Netrunner's answer to `walker --dmenu`, for the questions the web-app and
// keybind scripts ask through ~/.config/theme/prompt (PromptState). The question arrives as a
// holocall (widgets/Holocall.qml) from the script that asks (request.json's `from`): it speaks the
// question, and you answer on the reply line or, when there are options, pick one of them as the
// game's dialogue choices. Type to filter, ↑ ↓ / Tab choose, Enter answers (the call hangs up),
// Esc cancels (the signal drops). No match: Enter answers with what you typed.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: PromptState.open || call.busy

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-prompt"
    WlrLayershell.keyboardFocus: PromptState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: PromptState.open ? null : noInput
    Region { id: noInput }

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

    // who's calling: the script that asked, with a face to match
    readonly property string from: (req.from ?? "").trim()
    function avatarFor(name) {
        if (/key/i.test(name)) return "preferences-desktop-keyboard-shortcuts";
        if (/web|url|brow/i.test(name)) return "applications-internet";
        if (/theme|setup|wall/i.test(name)) return "preferences-desktop-theme";
        return "dialog-question";
    }

    // the call ends first: answering closes PromptState, which would otherwise read as a drop
    function submit() {
        if (!PromptState.open) return;
        call.hangUp();
        if (choosing && filtered.length > 0) {
            const o = filtered[Math.min(sel, filtered.length - 1)];
            PromptState.answer(req.index ? String(o.i) : o.text);
        } else if (req.index) PromptState.answer("");
        else PromptState.answer(query);
    }
    function cancel() {
        if (!PromptState.open) return;
        call.drop();
        PromptState.cancel();
    }
    function step(d) {
        const n = filtered.length;
        if (n > 0) sel = (sel + d + n) % n;
    }

    Connections {
        target: PromptState
        function onDirChanged() {
            if (PromptState.open) {
                root.query = "";
                root.sel = 0;
                root.pointer = Qt.point(-1, -1);
                field.focusField();
                call.call();
            } else call.drop();      // cancelled from outside (qs ipc call prompt cancel)
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.6 * call.presence) }
    MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    MouseArea { x: call.x; y: call.y; width: call.width; height: call.height }     // clicks on the call stay there

    Holocall {
        id: call
        width: Math.min(900, root.width - 64)
        height: implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.2)
        caller: (root.from || "unknown caller").toUpperCase()
        avatar: root.avatarFor(root.from)
        line: root.req.placeholder || "Enter a value."
        tint: Theme.cyan
        tag: "INPUT REQUIRED"
        jp: "入力"
        hints: root.choosing ? "↑↓ CHOOSE   //   ENTER ANSWER   //   ESC HANG UP" : "ENTER ANSWER   //   ESC HANG UP"

        Column {
            width: parent.width
            spacing: 10

            Field {
                id: field
                width: parent.width
                height: 38
                opacity: call.appear(0)
                text: root.query
                accent: Theme.cyan
                placeholder: root.choosing ? "type to filter" : "reply"
                onEdited: root.query = text
                onAccepted: root.submit()
                input.font.pixelSize: 16
                input.Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape) { root.cancel(); e.accepted = true; }
                    else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { root.step(1); e.accepted = true; }
                    else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { root.step(-1); e.accepted = true; }
                }
            }

            // the dialogue choices
            ListView {
                id: list
                visible: root.choosing
                width: parent.width
                height: Math.min(contentHeight, 42 * 8)
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.choosing ? root.filtered : []
                currentIndex: root.sel
                highlightMoveDuration: Theme.fast
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.sel
                    readonly property real arrived: call.appear(index + 1)
                    width: list.width
                    height: 40
                    opacity: arrived
                    Rectangle {
                        x: (1 - row.arrived) * 22
                        width: parent.width - x
                        height: parent.height
                        color: row.sel ? Theme.alpha(Theme.yellow, 0.2) : "transparent"
                        Rectangle { visible: row.sel; width: 3; height: parent.height; color: Theme.yellow }
                        Text {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(row.modelData.i + 1).padStart(2, "0")
                            color: row.sel ? Theme.yellow : Theme.alpha(Theme.yellow, 0.45)
                            font.family: Theme.mono; font.pixelSize: Theme.label
                        }
                        Text {
                            x: 46
                            width: parent.width - x - 64
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.modelData.text
                            color: row.sel ? Theme.bright : Theme.alpha(Theme.yellow, 0.85)
                            font.family: Theme.condensed; font.pixelSize: 19; font.weight: Font.DemiBold
                        }
                        Rectangle {
                            visible: row.sel
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34; height: 22
                            color: "transparent"
                            border.width: 1; border.color: Theme.yellow
                            Text { anchors.centerIn: parent; text: "↵"; color: Theme.yellow; font.family: Theme.mono; font.pixelSize: 13; font.weight: Font.Bold }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onPositionChanged: m => {         // only a pointer that really moves picks (not one that sat there as the call opened)
                            const p = mapToGlobal(m.x, m.y);
                            if (root.pointer.x < 0) root.pointer = p;
                            else if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.sel = row.index; }
                        }
                        onClicked: { root.sel = row.index; root.submit(); }
                    }
                }
            }
            Label {
                visible: root.choosing && root.filtered.length === 0
                text: root.req.index ? "NO MATCH" : "NO MATCH  //  ENTER ANSWERS WITH WHAT YOU TYPED"
            }
        }
    }
}
