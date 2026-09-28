import QtQuick
import "../theme"
import "../widgets"

// One level of a menu cascade: a raised panel of rows. Hovering a row selects it and, after a
// moment, opens its submenu (or closes a sibling's); clicking runs it. Menus longer than the
// screen get 98's scroll arrows at the top and bottom. The Start menu's top level is "big": tall
// rows with large icons and the vertical banner down its left side.
Item {
    id: root

    required property var level
    required property int depth
    property real limitBottom: parent ? parent.height : 1000   // don't grow past this (the taskbar)
    property real limitRight: parent ? parent.width : 1000

    readonly property var items: level.items ?? []
    readonly property bool big: level.big ?? false
    readonly property bool banner: level.banner ?? false
    readonly property int rowH: big ? Theme.menuItemBig : Theme.menuItem
    readonly property int iconCol: big ? Theme.iconBig + 16 : Theme.icon + 12
    readonly property int bannerW: banner ? Theme.bannerWidth : 0

    readonly property real naturalH: items.reduce((h, it) => h + (it.sep ? 9 : rowH), 0) + (level.loading || !items.length ? rowH : 0)
    readonly property real maxH: limitBottom - 4
    readonly property bool scrolls: naturalH + 6 > maxH
    readonly property int arrowH: 16

    width: Math.max(big ? 250 : 170, bannerW + iconCol + measure.width + 34 + hintMeasure.width) + 6
    height: Math.min(naturalH + 6 + (scrolls ? arrowH * 2 : 0), maxH)
    x: level.ax + width > limitRight ? Math.max(0, level.altX - width) : level.ax
    y: level.up ? Math.max(0, level.ay - height) : Math.max(0, Math.min(level.ay, limitBottom - height))

    // widest label / hint, measured on their own so the rows can take the panel's width
    Column {
        id: measure
        visible: false
        Repeater { model: root.items; Txt { required property var modelData; text: modelData.text ?? ""; bold: modelData.bold ?? false } }
    }
    Column {
        id: hintMeasure
        visible: false
        Repeater { model: root.items; Txt { required property var modelData; text: modelData.hint ? modelData.hint + "    " : "" } }
    }

    // 98 menus slide out (Start: upwards)
    property real reveal: 0
    NumberAnimation on reveal { id: slide; from: 0; to: 1; duration: Theme.menuSlide; easing.type: Easing.OutQuad; running: true }
    // a different submenu at this depth (another item hovered): slide that one out too
    readonly property var from: level.from
    onFromChanged: slide.restart()

    Item {
        id: clipper
        width: root.width
        height: root.height * root.reveal
        y: root.level.up ? root.height - height : 0
        clip: true

        Item {
            width: root.width
            height: root.height
            y: root.level.up ? -(root.height - clipper.height) : 0

            Bevel { anchors.fill: parent; kind: "raised"; fill: Theme.face }

            // the banner: "Memphis 98" reading upwards on the title-bar gradient
            Rectangle {
                visible: root.banner
                x: 3; y: 3
                width: Theme.bannerWidth - 3
                height: parent.height - 6
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.title2 }
                    GradientStop { position: 1; color: Theme.title }
                }
                Row {
                    rotation: -90
                    transformOrigin: Item.TopLeft
                    x: 3
                    y: parent.height - 8
                    spacing: 2
                    Text {
                        text: "Memphis"
                        color: Theme.titleText
                        font.family: Theme.fontBanner
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        text: "98"
                        color: Theme.alpha(Theme.titleText, 0.85)
                        font.family: "Arial"
                        font.pixelSize: 22
                    }
                }
            }

            Flickable {
                id: flick
                x: 3 + root.bannerW
                y: 3 + (root.scrolls ? root.arrowH : 0)
                width: root.width - 6 - root.bannerW
                height: root.height - 6 - (root.scrolls ? root.arrowH * 2 : 0)
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
                            height: modelData.sep ? 9 : root.rowH

                            Sep { visible: row.modelData.sep ?? false; y: 4; x: 1; width: parent.width - 2 }

                            Rectangle {
                                anchors.fill: parent
                                visible: row.sel && !row.modelData.sep
                                color: Theme.select
                            }
                            Icon {
                                visible: !row.modelData.sep && (row.modelData.icon ?? "") !== ""
                                x: (root.iconCol - size) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.icon ?? ""
                                size: root.big ? Theme.iconBig : Theme.icon
                                opacity: row.on ? 1 : 0.5
                            }
                            Glyph {
                                visible: (row.modelData.check || row.modelData.radio) === true
                                x: (root.iconCol - width) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                kind: row.modelData.radio ? "dot" : "check"
                                color: row.sel ? Theme.selectText : Theme.text
                            }
                            Txt {
                                visible: !row.modelData.sep
                                x: root.iconCol
                                height: parent.height
                                text: row.modelData.text ?? ""
                                bold: row.modelData.bold ?? false
                                enabled: row.on
                                color: !row.on ? Theme.grayText : row.sel ? Theme.selectText : Theme.text
                                style: row.on || row.sel ? Text.Normal : Text.Raised
                            }
                            Txt {
                                visible: (row.modelData.hint ?? "") !== ""
                                anchors.right: parent.right
                                anchors.rightMargin: 24
                                height: parent.height
                                text: row.modelData.hint ?? ""
                                color: row.sel ? Theme.selectText : Theme.text
                            }
                            Glyph {
                                visible: row.modelData.sub !== undefined
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "right"
                                color: row.sel ? Theme.selectText : row.on ? Theme.text : Theme.grayText
                            }

                            function geom() {
                                const p = row.mapToItem(root.parent, 0, 0);
                                return { left: root.x, right: root.x + root.width, y: p.y };
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !row.modelData.sep
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
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
                    // while a submenu's entries load, or when it has none
                    Txt {
                        visible: root.level.loading || root.items.length === 0
                        x: root.iconCol
                        height: root.rowH
                        text: root.level.loading ? "Please wait…" : "(Empty)"
                        enabled: false
                    }
                }
            }

            // scroll arrows (long menus)
            Repeater {
                model: root.scrolls ? [-1, 1] : []
                Item {
                    required property int modelData
                    x: 3 + root.bannerW
                    y: modelData < 0 ? 3 : root.height - 3 - root.arrowH
                    width: root.width - 6 - root.bannerW
                    height: root.arrowH
                    Glyph { anchors.centerIn: parent; kind: parent.modelData < 0 ? "up" : "down"; color: Theme.text }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        Timer {
                            running: parent.containsMouse
                            interval: 40
                            repeat: true
                            triggeredOnStart: true
                            onTriggered: flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + parent.parent.modelData * 12))
                        }
                    }
                }
            }
        }
    }

    // keep the keyboard selection in view
    Connections {
        target: root
        function onLevelChanged() {
            const i = root.level.sel;
            if (i < 0 || !root.scrolls) return;
            let top = 0;
            for (let k = 0; k < i; k++) top += root.items[k].sep ? 9 : root.rowH;
            if (top < flick.contentY) flick.contentY = top;
            else if (top + root.rowH > flick.contentY + flick.height) flick.contentY = top + root.rowH - flick.height;
        }
    }

    Timer {
        id: hoverOpen
        property Item target
        interval: Theme.menuDelay
        onTriggered: {
            if (!target || root.level.sel !== target.index) return;
            if (target.modelData.sub) {
                const g = target.geom();
                Menus.openSub(root.depth, target.index, g.right, g.left, g.y, false);
            } else if (Menus.levels.length > root.depth + 1) Menus.closeFrom(root.depth + 1);
        }
    }

    // Position of a row, for keyboard-opened submenus
    function rowGeom(i) {
        let top = 0;
        for (let k = 0; k < i; k++) top += items[k].sep ? 9 : rowH;
        return { left: x, right: x + width, y: y + 3 + (scrolls ? arrowH : 0) + top - flick.contentY };
    }
}
