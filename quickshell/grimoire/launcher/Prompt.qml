import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// A question for you: Grimoire's answer to `walker --dmenu`, for what the web-app and keybind scripts
// ask through ~/.config/theme/prompt (PromptState). A leaf of parchment in a frame of the theme's
// leather tooled in gilt (the arcana's card backs): the question at its head, a line to write the
// answer on, and when there are choices, the choices, numbered in red. Type to narrow them, ↑ ↓ / Tab
// choose, Enter answers, Esc cancels; with no match, Enter answers with what you wrote.
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
    WlrLayershell.namespace: "grimoire-prompt"
    WlrLayershell.keyboardFocus: PromptState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: PromptState.open ? null : noInput
    Region { id: noInput }

    property real shown: PromptState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    readonly property var req: PromptState.request
    readonly property bool choosing: !req.input && (req.options ?? []).length > 0
    property string query: ""
    property int sel: 0

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
        function onDirChanged() {
            if (PromptState.open) { root.query = ""; input.text = ""; root.sel = 0; input.forceActiveFocus(); }
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.mix(Theme.veil, "#000000", 0.3), 0.5 * root.shown) }
    MouseArea { anchors.fill: parent; onClicked: PromptState.cancel() }

    Item {
        id: card
        width: Math.min(560, root.width - 60)
        height: 130 + 70 + (root.choosing ? list.height + 16 : 0) + 40
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.24) - (1 - root.shown) * 16
        opacity: root.shown
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 14; anchors.bottomMargin: -24; anchors.leftMargin: 4; anchors.rightMargin: -10
            radius: 16
            color: Qt.alpha("#000000", 0.6)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
        }
        Cover {
            id: frame
            anchors.fill: parent
            radius: 14; bevel: 10; wear: 0.5; seed: 0.62
            color: Theme.leather
            light: Qt.vector3d(width * 0.25, -height * 0.3, 700)
            lightPower: 1.2; ambient: 0.6
            lightColor: Theme.mix(Theme.flame, "#ffffff", 0.55)
            Rectangle { anchors.fill: parent; anchors.margins: 9; radius: 8; color: "transparent"; border.width: 1.3; border.color: frame.gilt }
            Rectangle { anchors.fill: parent; anchors.margins: 13; radius: 6; color: "transparent"; border.width: 0.8; border.color: frame.gilt }
        }

        // the question
        Column {
            id: head
            anchors.horizontalCenter: parent.horizontalCenter
            y: 26
            width: parent.width - 80
            spacing: 2
            Caps {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "a question"
                color: Theme.alpha(Theme.gold, 0.75)
                font.pixelSize: 11
                font.letterSpacing: 4
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.req.placeholder || (root.choosing ? "Choose one" : "Write your answer")
                color: Theme.goldBright
                font.family: Theme.display; font.weight: Font.DemiBold
                font.pixelSize: 24
            }
        }

        // the leaf
        Parchment {
            id: leaf
            x: 20
            y: 100
            width: parent.width - 40
            height: parent.height - y - 40
            radius: 4
            age: 0.35

            Item {
                id: line
                x: 26; y: 18
                width: parent.width - 52
                height: 34
                Text {
                    id: quill
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✦"
                    color: Theme.rubric
                    font.family: Theme.symbols
                    font.pixelSize: 12
                }
                TextInput {
                    id: input
                    anchors.left: quill.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.ink
                    selectionColor: Theme.alpha(Theme.rubric, 0.3)
                    font.family: Theme.body
                    font.italic: true
                    font.pixelSize: 20
                    focus: true
                    cursorDelegate: Rectangle { width: 1.5; color: Theme.rubric }
                    onTextEdited: root.query = text
                    Keys.onPressed: e => {
                        const k = e.key;
                        if (k === Qt.Key_Escape) PromptState.cancel();
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.submit();
                        else if (k === Qt.Key_Down || k === Qt.Key_Tab) root.step(1);
                        else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.step(-1);
                        else return;
                        e.accepted = true;
                    }
                    Body {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.choosing ? "write to narrow, or choose below…" : "write here…"
                        italic: true
                        color: Theme.alpha(Theme.inkDim, 0.7)
                        font.pixelSize: 20
                    }
                }
            }
            GoldRule { x: line.x; y: line.y + line.height + 2; width: line.width; color: Theme.alpha(Theme.inkDim, 0.55); ornament: "" }

            ListView {
                id: list
                visible: root.choosing
                x: 14
                y: line.y + line.height + 16
                width: parent.width - 28
                height: Math.min(8, Math.max(1, count)) * 42
                clip: true
                model: root.filtered
                currentIndex: root.sel
                highlightMoveDuration: Theme.fast
                boundsBehavior: Flickable.StopAtBounds
                highlight: Item {
                    Rectangle { anchors.fill: parent; radius: 3; color: Theme.alpha(Theme.rubric, 0.09) }
                    Rectangle { width: 2; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter; color: Theme.rubric }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 42
                    Body {
                        x: 12; width: 36
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.roman(row.index + 1).toLowerCase() + "."
                        italic: true
                        color: Theme.rubric
                        font.pixelSize: 13
                    }
                    Body {
                        x: 50
                        width: parent.width - x - 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.text
                        font.pixelSize: 17
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.sel = row.index
                        onClicked: { root.sel = row.index; root.submit(); }
                    }
                }
            }
        }

        Caps {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: root.choosing ? "↑ ↓  choose   ·   enter  answers   ·   esc  declines" : "enter  answers   ·   esc  declines"
            color: Theme.alpha(Theme.gold, 0.5)
            font.pixelSize: 10
            font.letterSpacing: 3
        }
    }
}
