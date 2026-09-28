import QtQuick
import "../theme"

// A list view in 98's "details" style: a sunken white box, optional column headers (raised
// buttons), one row per item with a small icon, the selection in the highlight colour.
//   model     array of anything
//   columns   [{ title, width (px, or 0 = the rest), text: item => string }]; one column if empty
//   iconOf    item => theme icon name ("" for none)
//   textOf    item => string (single-column lists)
// clicked(i) on a click, activated(i) on a double click or Enter.
Bevel {
    id: root

    property var model: []
    property var columns: []
    property var iconOf: null
    property var textOf: item => String(item)
    property var colorOf: null          // item => colour for the row's text (or undefined)
    property int currentIndex: -1
    property int rowHeight: Theme.menuItem - 2
    property bool headers: columns.length > 0
    property alias view: list

    signal clicked(int index)
    signal activated(int index)
    signal rightClicked(int index, real x, real y)

    kind: "sunken"
    fill: Theme.window
    implicitWidth: 300
    implicitHeight: 200
    activeFocusOnTab: true

    Keys.onUpPressed: { if (currentIndex > 0) { currentIndex--; clicked(currentIndex); list.positionViewAtIndex(currentIndex, ListView.Contain); } }
    Keys.onDownPressed: { if (currentIndex < model.length - 1) { currentIndex++; clicked(currentIndex); list.positionViewAtIndex(currentIndex, ListView.Contain); } }
    Keys.onReturnPressed: if (currentIndex >= 0) activated(currentIndex)

    readonly property var widths: {
        const w = list.width;
        const fixed = columns.reduce((s, c) => s + (c.width || 0), 0);
        const flex = columns.filter(c => !c.width).length;
        return columns.map(c => c.width || Math.max(40, (w - fixed) / Math.max(1, flex)));
    }

    Row {
        id: header
        visible: root.headers
        x: 2; y: 2
        height: visible ? Theme.button - 6 : 0
        Repeater {
            model: root.columns
            Bevel {
                required property var modelData
                required property int index
                kind: "button"
                fill: Theme.face
                width: root.widths[index] ?? 80
                height: header.height
                Txt { x: 6; height: parent.height; width: parent.width - 10; elide: Text.ElideRight; text: modelData.title ?? "" }
            }
        }
    }

    ListView {
        id: list
        x: 2
        y: 2 + header.height
        width: parent.width - 4 - (bar.visible ? bar.width : 0)
        height: parent.height - 4 - header.height
        clip: true
        model: root.model
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: index === root.currentIndex
            width: list.width
            height: root.rowHeight

            Rectangle {
                anchors.fill: parent
                visible: row.sel
                color: root.activeFocus || list.activeFocus ? Theme.select : Theme.select
            }
            Icon {
                id: ic
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: name !== ""
                name: root.iconOf ? (root.iconOf(row.modelData) ?? "") : ""
                size: Theme.icon
            }
            Row {
                x: ic.visible ? ic.width + 10 : 6
                height: parent.height
                Repeater {
                    model: root.columns.length ? root.columns : [{}]
                    Txt {
                        required property var modelData
                        required property int index
                        width: root.columns.length ? (root.widths[index] ?? 80) - (index === 0 ? (ic.visible ? ic.width + 10 : 6) : 0) : list.width - x - 6
                        height: row.height
                        leftPadding: index === 0 ? 0 : 6
                        elide: Text.ElideRight
                        text: root.columns.length ? (modelData.text ? modelData.text(row.modelData) : "") : root.textOf(row.modelData)
                        color: row.sel ? Theme.selectText : (root.colorOf ? (root.colorOf(row.modelData) ?? Theme.windowText) : Theme.windowText)
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => {
                    root.forceActiveFocus();
                    root.currentIndex = row.index;
                    root.clicked(row.index);
                    if (e.button === Qt.RightButton) {
                        const p = row.mapToItem(root, e.x, e.y);
                        root.rightClicked(row.index, p.x, p.y);
                    }
                }
                onDoubleClicked: root.activated(row.index)
            }
        }
    }
    Scroll {
        id: bar
        flick: list
        x: parent.width - width - 2
        y: list.y
        height: list.height
    }
}
