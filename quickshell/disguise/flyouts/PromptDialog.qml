import QtQuick
import "../theme"
import "../widgets"

// A Windows 11 content dialog for the questions the web-app and keybind scripts ask through
// ~/.config/theme/prompt (PromptState): the question as the title, a text box or a list to choose
// from, and the footer with the accent OK and Cancel. Type to filter a list, ↑ ↓ choose, Enter
// answers, Esc cancels; with nothing matching, OK answers with what you typed (as Walker does).
Item {
    id: root

    property string screenName
    property bool active: false

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
    onActiveChanged: if (active) { query = ""; sel = 0; focusLater.restart(); }
    Timer { id: focusLater; interval: 30; onTriggered: field.input.forceActiveFocus() }

    // the dialog grows with its list
    implicitHeight: 196 + (choosing ? Math.max(40, Math.min(list.contentHeight, 36 * 8)) + 12 : 0)

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

    Acrylic { anchors.fill: parent; tint: Theme.mica; tintAlpha: 1 }

    Column {
        x: 24; y: 24
        width: parent.width - 48
        spacing: 12
        Txt {
            width: parent.width
            wrapMode: Text.Wrap
            text: root.req.placeholder || "Enter a value"
            size: Theme.subtitle
            strong: true
        }
        Field {
            id: field
            width: parent.width
            height: Theme.controlHeight
            placeholder: root.choosing ? "Type to filter" : ""
            text: root.query
            onAccepted: root.submit()
            input.onTextEdited: root.query = input.text
            input.Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { PromptState.cancel(); e.accepted = true; }
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { root.step(1); e.accepted = true; }
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { root.step(-1); e.accepted = true; }
            }
        }
        ListView {
            id: list
            visible: root.choosing
            width: parent.width
            height: visible ? Math.max(40, Math.min(contentHeight, 36 * 8)) : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.choosing ? root.filtered : []
            currentIndex: root.sel
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === root.sel
                width: list.width
                height: 36
                Rectangle {
                    anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: 2
                    radius: Theme.radius
                    color: row.sel ? Theme.subtle : rowMouse.containsMouse ? Theme.subtle2 : "transparent"
                    Rectangle {     // WinUI's selection pill
                        visible: row.sel
                        x: 0; anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 16; radius: 1.5
                        color: Theme.accent
                    }
                }
                Txt { x: 14; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: row.modelData.text }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: m => { const p = mapToGlobal(m.x, m.y); if (p.x !== root.pointer.x || p.y !== root.pointer.y) { root.pointer = p; root.sel = row.index; } }
                    onClicked: { root.sel = row.index; root.submit(); }
                }
            }
            Txt {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                level: 2
                text: root.req.index ? "No matches" : "No matches. OK uses what you typed."
            }
        }
    }

    // the footer, a shade darker, with the buttons at the right
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 80
        color: Theme.micaAlt
        bottomLeftRadius: Theme.radiusLarge
        bottomRightRadius: Theme.radiusLarge
        Rectangle { width: parent.width; height: 1; color: Theme.divider }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Btn { width: 120; kind: "accent"; text: "OK"; onClicked: root.submit() }
            Btn { width: 120; text: "Cancel"; onClicked: PromptState.cancel() }
        }
    }
}
