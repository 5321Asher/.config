import QtQuick
import "../theme"
import "../widgets"

// One level of a menu cascade, as a quickhack list: a dark cut-corner panel, rows in tracked
// caps, the selected row lit in red with a bar down its left edge. The hub's top level is "big":
// each row gets a two-digit code and its subtext. Hovering opens submenus after a moment;
// long menus scroll (arrows at the ends). Rows are Menus items (see Menus.qml).
Item {
    id: root

    required property var level
    required property int depth
    property real limitBottom: parent ? parent.height : 1000
    property real limitRight: parent ? parent.width : 1000

    readonly property var items: level.items ?? []
    readonly property bool big: level.big ?? false
    readonly property int rowH: big ? 46 : 30
    readonly property int sepH: 11

    readonly property real naturalH: items.reduce((h, it) => h + (it.sep ? sepH : rowH), 0) + (level.loading || !items.length ? rowH : 0)
    readonly property real maxH: limitBottom - 8
    readonly property bool scrolls: naturalH + 12 > maxH
    readonly property int arrowH: 16

    width: Math.max(big ? 320 : 220, measure.width + (big ? 110 : 78) + hintMeasure.width)
    height: Math.min(naturalH + 12 + (scrolls ? arrowH * 2 : 0), maxH)
    x: level.ax + width > limitRight ? Math.max(0, level.altX - width) : level.ax
    y: level.up ? Math.max(0, level.ay - height) : Math.max(0, Math.min(level.ay, limitBottom - height))

    Column {
        id: measure
        visible: false
        Repeater { model: root.items; Label { required property var modelData; text: modelData.text ?? ""; strong: true
                                              font.pixelSize: root.big ? Theme.data : Theme.label + 1 } }
    }
    Column {
        id: hintMeasure
        visible: false
        Repeater { model: root.items; Label { required property var modelData; text: modelData.hint ? modelData.hint + "  " : "" } }
    }

    // arrival: a fast wipe from the left, with the rows decoding
    property real reveal: 0
    NumberAnimation on reveal { id: slide; from: 0; to: 1; duration: Theme.normal; easing.type: Theme.easing; running: true }
    readonly property var from: level.from
    onFromChanged: slide.restart()

    Item {
        width: root.width * root.reveal
        height: root.height
        clip: true

        Chamfer {
            width: root.width
            height: root.height
            cut: Theme.chamfer
            corners: "tr bl"
            fill: Theme.alpha(Theme.bgDark, 0.94)
            stroke: root.depth === 0 && root.big ? Theme.alpha(Theme.red, 0.7) : Theme.alpha(Theme.line, 1)
        }
        Rectangle { visible: root.big; x: 0; y: 0; width: 3; height: 24; color: Theme.red }

        Flickable {
            id: flick
            x: 6
            y: 6 + (root.scrolls ? root.arrowH : 0)
            width: root.width - 12
            height: root.height - 12 - (root.scrolls ? root.arrowH * 2 : 0)
            contentHeight: rows.height
            interactive: false
            clip: true

            Column {
                id: rows
                width: flick.width

                Repeater {
                    model: root.items
                    Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool sel: root.level.sel === index
                        readonly property bool on: modelData.enabled !== false
                        width: rows.width
                        height: modelData.sep ? root.sepH : root.rowH

                        Rectangle {
                            visible: row.modelData.sep ?? false
                            y: 5; x: 6
                            width: parent.width - 12; height: 1
                            color: Theme.line
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: row.sel && !row.modelData.sep
                            color: Theme.alpha(Theme.red, 0.16)
                            Rectangle { width: 3; height: parent.height; color: Theme.red }
                        }

                        // the code ("01") on the hub's rows; a check mark or dot for toggles
                        Text {
                            visible: root.big && !row.modelData.sep
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(root.items.slice(0, row.index + 1).filter(it => !it.sep).length).padStart(2, "0")
                            color: row.sel ? Theme.red : Theme.dim
                            font.family: Theme.display
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }
                        Text {
                            visible: !root.big && ((row.modelData.check || row.modelData.radio) === true)
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.radio ? "◆" : "■"
                            color: Theme.red
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                        Column {
                            visible: !row.modelData.sep
                            x: root.big ? 52 : 26
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 30
                            spacing: 1
                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.text ?? ""
                                strong: true
                                font.pixelSize: root.big ? Theme.data : Theme.label + 1
                                color: !row.on ? Theme.alpha(Theme.dim, 0.6) : row.sel ? Theme.bright : Theme.fg
                            }
                            Label {
                                visible: root.big && (row.modelData.sub_text ?? "") !== ""
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.sub_text ?? ""
                                font.pixelSize: Theme.label - 1
                                color: row.sel ? Theme.cyan : Theme.dim
                            }
                        }
                        Label {
                            visible: (row.modelData.hint ?? "") !== ""
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.hint ?? ""
                        }
                        Text {
                            visible: row.modelData.sub !== undefined
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "▸"
                            color: row.sel ? Theme.red : Theme.dim
                            font.family: Theme.mono
                            font.pixelSize: Theme.data
                        }

                        function geom() {
                            const p = row.mapToItem(root.parent, 0, 0);
                            return { left: root.x, right: root.x + root.width, y: p.y };
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !row.modelData.sep
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                Menus.setSel(root.depth, row.index);
                                hoverOpen.target = row;
                                hoverOpen.restart();
                            }
                            onClicked: {
                                hoverOpen.stop();
                                if (row.modelData.sub) {
                                    const g = row.geom();
                                    Menus.openSub(root.depth, row.index, g.right, g.left, g.y, false);
                                } else Menus.activate(root.depth, row.index, null);
                            }
                        }
                    }
                }
                Label {
                    visible: root.level.loading || root.items.length === 0
                    x: 26
                    height: root.rowH
                    text: root.level.loading ? "LINKING…" : "// EMPTY"
                }
            }
        }

        // scroll arrows (long menus)
        Repeater {
            model: root.scrolls ? [-1, 1] : []
            Item {
                required property int modelData
                x: 6
                y: modelData < 0 ? 6 : root.height - 6 - root.arrowH
                width: root.width - 12
                height: root.arrowH
                Text { anchors.centerIn: parent; text: parent.modelData < 0 ? "▲" : "▼"; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 9 }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    Timer {
                        running: parent.containsMouse
                        interval: 40
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + parent.parent.modelData * 14))
                    }
                }
            }
        }
    }

    // keep the keyboard selection in view
    onLevelChanged: {
        const i = level.sel;
        if (i < 0 || !scrolls) return;
        let top = 0;
        for (let k = 0; k < i; k++) top += items[k].sep ? sepH : rowH;
        if (top < flick.contentY) flick.contentY = top;
        else if (top + rowH > flick.contentY + flick.height) flick.contentY = top + rowH - flick.height;
    }

    Timer {
        id: hoverOpen
        property Item target
        interval: 260
        onTriggered: {
            if (!target || root.level.sel !== target.index) return;
            if (target.modelData.sub) {
                const g = target.geom();
                Menus.openSub(root.depth, target.index, g.right, g.left, g.y, false);
            } else if (Menus.levels.length > root.depth + 1) Menus.closeFrom(root.depth + 1);
        }
    }

    function rowGeom(i) {
        let top = 0;
        for (let k = 0; k < i; k++) top += items[k].sep ? sepH : rowH;
        return { left: x, right: x + width, y: y + 6 + (scrolls ? arrowH : 0) + top - flick.contentY };
    }
}
