import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

// The prompt plate: Observatory's answer to `walker --dmenu`, for the questions the web-app and
// keybind scripts ask through ~/.config/theme/prompt (PromptState). A brass plate with the question
// engraved on it, a phosphor entry line, and — when there are choices — a ledger to pick from.
// Type to filter, ↑ ↓ / Tab choose, Enter answers, Esc cancels. With no match, Enter answers with
// the typed text (as Walker does).
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden: moving a shown window rebuilds its surface
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
    WlrLayershell.namespace: "observatory-prompt"
    WlrLayershell.keyboardFocus: PromptState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real shown: PromptState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

    readonly property var req: PromptState.request
    readonly property bool choosing: !req.input && (req.options ?? []).length > 0
    property string query: ""
    property int sel: 0
    // Where the pointer last really moved (screen coords): rows that scroll under a still cursor
    // mustn't take the selection, or stepping up past the top of the view jumps back down
    property point pointer: Qt.point(-1, -1)

    // [{text, i}] where i is the option's line in the request
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
        } else if (req.index) {
            PromptState.answer("");         // nothing picked: an index can't be typed
        } else {
            PromptState.answer(query);
        }
    }
    function step(d) {
        const n = filtered.length;
        if (n > 0) sel = (sel + d + n) % n;
    }

    Connections {
        target: PromptState
        function onDirChanged() {
            if (PromptState.open) { root.query = ""; root.sel = 0; input.forceActiveFocus(); }
        }
    }

    // ---------------------------------------------------------------- backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDark, Theme.chartDim * root.shown)
    }
    MouseArea {
        anchors.fill: parent
        onClicked: PromptState.cancel()
    }

    // ---------------------------------------------------------------- the plate
    Item {
        id: plate
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.26)
        width: Math.min(Theme.promptWidth, parent.width - 48)
        height: body.implicitHeight + 2 * Theme.transmissionPad + 8
        opacity: root.shown
        scale: 0.96 + 0.04 * root.shown

        Plate { anchors.fill: parent }
        MouseArea { anchors.fill: parent }      // clicks on the plate don't cancel

        Column {
            id: body
            x: Theme.transmissionPad + 6
            y: Theme.transmissionPad + 4
            width: parent.width - 2 * (Theme.transmissionPad + 6)
            spacing: 10

            Row {
                width: parent.width
                spacing: 10
                Rectangle {
                    width: 8; height: 8; rotation: 45
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.phosphor
                }
                Text {
                    width: parent.width - 18
                    elide: Text.ElideRight
                    text: root.req.placeholder || "enquiry"
                    color: Theme.brass
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.brass, 0.3) }

            // Entry line
            Item {
                width: parent.width
                height: 38
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Theme.alpha(Theme.bg, 0.9)
                    border.width: 1.4
                    border.color: Theme.brassBright
                }
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: root.choosing ? "type to narrow the ledger" : "type, then enter"
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize
                }
                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.phosphor
                    selectionColor: Theme.brassMuted
                    selectedTextColor: Theme.starlight
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize + 2
                    focus: PromptState.open
                    text: root.query
                    onTextEdited: root.query = text
                    Keys.onPressed: event => {
                        const k = event.key;
                        if (k === Qt.Key_Escape) PromptState.cancel();
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.submit();
                        else if (k === Qt.Key_Down || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) root.step(1);
                        else if (k === Qt.Key_Up || k === Qt.Key_Backtab) root.step(-1);
                        else return;
                        event.accepted = true;
                    }
                }
            }

            // Ledger of choices
            Item {
                width: parent.width
                visible: root.choosing
                height: visible ? Math.min(ledger.contentHeight, Theme.promptRow * Theme.promptRows) : 0

                ListView {
                    id: ledger
                    anchors.fill: parent
                    clip: true
                    model: root.choosing ? root.filtered : []
                    currentIndex: root.sel
                    highlightMoveDuration: Theme.fast
                    highlight: Rectangle {
                        width: ledger.width
                        color: Theme.alpha(Theme.brassMuted, 0.6)
                        Rectangle { width: 2; height: parent.height; color: Theme.brassBright }
                    }
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: ledger.width
                        height: Theme.promptRow
                        Text {
                            x: 12
                            width: parent.width - 24
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: row.modelData.text
                            color: row.index === root.sel ? Theme.starlight : Theme.fg
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: mouse => { const p = mapToGlobal(mouse.x, mouse.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.sel = row.index; } }
                            onClicked: { root.sel = row.index; root.submit(); }
                        }
                    }
                }
            }
            Text {
                visible: root.choosing && root.filtered.length === 0
                text: root.req.index ? "no match" : "no match · enter answers with what you typed"
                color: Theme.dim
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall + 1
            }

            Text {
                anchors.right: parent.right
                text: root.choosing ? "↑ ↓  choose   ·   enter  answer   ·   esc  cancel"
                                    : "enter  answer   ·   esc  cancel"
                color: Theme.alpha(Theme.dim, 0.9)
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
        }
    }
}
