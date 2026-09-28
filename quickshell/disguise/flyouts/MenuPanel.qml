import QtQuick
import Quickshell
import "../theme"
import "../widgets"

// One level of a context menu, Windows 11 style: Acrylic, 8 px corners, 32 px rows with an icon
// column, the shortcut or a chevron at the right, a rounded highlight under the pointer.
// Keyboard: up / down, right or Enter opens a submenu, left goes back, Esc closes.
Item {
    id: root

    required property int depth
    required property var level
    required property real areaWidth
    required property real areaHeight

    readonly property var items: level.items ?? []
    readonly property bool hasIcons: items.some(i => i.glyph || i.icon || i.check || i.radio)
    readonly property real contentW: Math.max(Theme.menuWidth - 40, ...items.map(i => measure.width(i)))
    width: Math.min(areaWidth - 16, contentW + 16)
    height: Math.max(40, items.reduce((h, i) => h + (i.sep ? 9 : Theme.menuRow + 2), 0) + 8)
    // place: at (x, y), opening upwards when asked (the taskbar's menus); kept on screen; a
    // submenu flips to the left of its parent if there's no room at the right
    x: {
        let px = level.x;
        if (level.up && depth === 0) px = level.x - width / 2;
        if (px + width > areaWidth - 8) px = level.altX !== undefined ? level.altX - width : areaWidth - 8 - width;
        return Math.max(8, px);
    }
    y: {
        let py = level.up ? level.y - height : level.y;
        if (py + height > areaHeight - 8) py = areaHeight - 8 - height;
        return Math.max(8, py);
    }

    // row widths, for the menu's width
    QtObject {
        id: measure
        function width(i) {
            if (i.sep) return 0;
            probe.text = i.text ?? "";
            hintProbe.text = i.hint ?? "";
            return (root.hasIcons ? 40 : 12) + probe.implicitWidth + (i.hint ? hintProbe.implicitWidth + 24 : 0) + (i.sub ? 36 : 16);
        }
    }
    Txt { id: probe; visible: false }
    Txt { id: hintProbe; visible: false; size: Theme.caption }

    // appears with a short fade and a small slide, as Windows' menus do
    opacity: 0
    transform: Translate { id: shift; y: root.level.up ? 8 : -8 }
    Component.onCompleted: { opacity = 1; shift.y = 0; }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    Acrylic {
        anchors.fill: parent
        tintAlpha: Theme.dark ? 0.92 : 0.9
    }
    MouseArea { anchors.fill: parent }     // clicks on the menu don't fall through to "close"

    Column {
        id: col
        x: 4; y: 4
        width: parent.width - 8
        Repeater {
            model: root.items
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: root.level.sel === index
                width: col.width
                height: modelData.sep ? 9 : Theme.menuRow + 2
                Rectangle {
                    visible: row.modelData.sep ?? false
                    anchors.verticalCenter: parent.verticalCenter
                    x: -4; width: parent.width + 8; height: 1
                    color: Theme.divider
                }
                Rectangle {
                    visible: !row.modelData.sep
                    anchors.fill: parent
                    anchors.topMargin: 1; anchors.bottomMargin: 1
                    radius: Theme.radius
                    color: row.sel && row.modelData.enabled !== false ? (rowMouse.pressed ? Theme.subtle2 : Theme.subtle) : "transparent"
                }
                // icon column: a glyph, an app icon, or the check / radio mark
                Glyph {
                    visible: !row.modelData.sep && (row.modelData.glyph || row.modelData.check || row.modelData.radio) && !row.modelData.icon
                    x: 8; width: 20
                    anchors.verticalCenter: parent.verticalCenter
                    g: row.modelData.check ? "" : row.modelData.radio ? "" : (row.modelData.glyph ?? "")
                    size: row.modelData.radio ? 8 : 16
                    color: row.modelData.danger ? Theme.danger : Theme.text
                    opacity: row.modelData.enabled === false ? 0.4 : 1
                }
                AppIcon {
                    visible: !row.modelData.sep && !!row.modelData.icon
                    x: 10; size: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.modelData.icon ?? ""
                }
                Txt {
                    visible: !row.modelData.sep
                    x: root.hasIcons ? 40 : 12
                    width: parent.width - x - (row.modelData.hint ? 90 : 30)
                    height: parent.height
                    text: row.modelData.text ?? ""
                    color: row.modelData.enabled === false ? Theme.textDisabled : row.modelData.danger ? Theme.danger : Theme.text
                    font.weight: row.modelData.bold ? Font.DemiBold : Font.Normal
                }
                Txt {
                    visible: !!row.modelData.hint && !row.modelData.sub
                    anchors.right: parent.right; anchors.rightMargin: 12
                    height: parent.height
                    text: row.modelData.hint ?? ""
                    size: Theme.caption
                    level: 2
                }
                Glyph {
                    visible: !!row.modelData.sub
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    g: ""
                    size: 12
                    color: Theme.text2
                }
                function geom() {
                    const p = row.mapToItem(root.parent, 0, 0);
                    return { right: p.x + row.width + 4, left: p.x - 4, y: p.y };
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    enabled: !row.modelData.sep
                    hoverEnabled: true
                    onContainsMouseChanged: if (containsMouse) { Flyouts.setSel(root.depth, row.index); hoverOpen.restart(); }
                    onClicked: Flyouts.activate(root.depth, row.index, row.geom())
                }
                Timer {
                    id: hoverOpen
                    interval: 250
                    onTriggered: if (rowMouse.containsMouse && row.modelData.sub) { const g = row.geom(); Flyouts.openSub(root.depth, row.index, g.right, g.left, g.y); }
                }
            }
        }
    }
    Ring {
        visible: root.level.loading ?? false
        anchors.centerIn: parent
        width: 20; height: 20
        indeterminate: true
    }

    // keyboard (the deepest level has it)
    function key(e) {
        const n = items.length;
        const step = d => { let i = level.sel; for (let k = 0; k < n; k++) { i = ((i + d) % n + n) % n; if (!items[i].sep && items[i].enabled !== false) return i; } return level.sel; };
        if (e.key === Qt.Key_Down) Flyouts.setSel(depth, step(1));
        else if (e.key === Qt.Key_Up) Flyouts.setSel(depth, step(-1));
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Right) {
            const r = col.children[level.sel];
            if (level.sel >= 0 && r && (e.key !== Qt.Key_Right || items[level.sel].sub)) Flyouts.activate(depth, level.sel, r.geom());
        } else if (e.key === Qt.Key_Left && depth > 0) Flyouts.levels = Flyouts.levels.slice(0, depth);
        else return false;
        return true;
    }
}
