import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

// Where menus are drawn: a transparent full-screen overlay on the screen the menu was opened on.
// A click anywhere outside the menus closes them (as in 98). Keyboard: ↑ ↓ select, → / Enter open
// a submenu, ← / Esc close one, Enter runs, a letter jumps to the next item starting with it.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool mine: Menus.open && Menus.screen === modelData.name

    visible: mine
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "glyph-menu"
    WlrLayershell.keyboardFocus: mine ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onMineChanged: if (mine) keys.forceActiveFocus()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: Menus.close()
    }

    Item {
        id: stage
        anchors.fill: parent

        Repeater {
            id: panels
            // depths as a ScriptModel: opening a submenu adds a panel instead of rebuilding them all
            // (a plain count would recreate every level, and the Start menu would slide out again)
            model: ScriptModel { values: root.mine ? Menus.levels.map((_, i) => i) : [] }
            MenuPanel {
                required property int modelData
                depth: modelData
                level: Menus.levels[modelData] ?? ({ items: [] })
                limitBottom: stage.height - (0)
                limitRight: stage.width
            }
        }
    }

    FocusScope {
        id: keys
        focus: true
        Keys.onPressed: e => {
            const d = Menus.levels.length - 1;
            if (d < 0) return;
            const lv = Menus.levels[d];
            const items = lv.items ?? [];
            const sel = lv.sel;
            const k = e.key;
            if (k === Qt.Key_Down || k === Qt.Key_Tab) Menus.setSel(d, Menus.firstEnabled(items, sel + 1, 1));
            else if (k === Qt.Key_Up || k === Qt.Key_Backtab) Menus.setSel(d, Menus.firstEnabled(items, sel < 0 ? items.length - 1 : sel - 1, -1));
            else if (k === Qt.Key_Escape || k === Qt.Key_Left) {
                if (d === 0 && k === Qt.Key_Left) { e.accepted = true; return; }
                Menus.closeFrom(d);
            } else if (k === Qt.Key_Right || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                if (sel < 0) { if (k !== Qt.Key_Right) Menus.setSel(d, Menus.firstEnabled(items, 0, 1)); }
                else if (items[sel]?.sub) {
                    const p = panels.itemAt(d);
                    const g = p ? p.rowGeom(sel) : { left: 0, right: 0, y: 0 };
                    Menus.openSub(d, sel, g.right, g.left, g.y, true);
                } else if (k !== Qt.Key_Right) Menus.activate(d, sel, null);
            } else if (e.text && /\S/.test(e.text)) {
                const ch = e.text.toLowerCase();
                const n = items.length;
                for (let s = 1; s <= n; s++) {
                    const i = (Math.max(sel, -1) + s) % n;
                    if (!items[i].sep && items[i].enabled !== false && (items[i].text ?? "").toLowerCase().startsWith(ch)) {
                        Menus.setSel(d, i);
                        break;
                    }
                }
            } else return;
            e.accepted = true;
        }
    }
}
