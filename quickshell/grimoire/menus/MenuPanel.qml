import QtQuick
import QtQuick.Effects
import "../theme"
import "../widgets"

// One level of a menu cascade, as a slip of parchment. The table of contents (a "big" level) is set
// like a book's contents page: "Contents" in blackletter over a rule, then each entry with its
// chapter numeral in red ink, its name, a dotted leader and its subtext. Other levels are plain
// slips: rows in Cardo, a red check or lozenge for toggles, › for submenus. The selected row gets a
// wash of gold and a ❧ in the margin. Slips unroll downwards as they arrive; long ones scroll.
Item {
    id: root

    required property var level
    required property int depth
    property real limitBottom: parent ? parent.height : 1000
    property real limitRight: parent ? parent.width : 1000

    readonly property var items: level.items ?? []
    readonly property bool big: level.big ?? false
    readonly property int rowH: big ? 46 : 30
    readonly property int sepH: 15
    readonly property int headH: big ? 66 : 0
    readonly property int padY: big ? 12 : 8

    readonly property real naturalH: headH + items.reduce((h, it) => h + (it.sep ? sepH : rowH), 0) + (level.loading || !items.length ? rowH : 0)
    readonly property real maxH: limitBottom - 12
    readonly property bool scrolls: naturalH + padY * 2 > maxH
    readonly property int arrowH: 16

    width: Math.max(big ? 400 : 230, measure.width + (big ? 190 : 90) + hintMeasure.width)
    height: Math.min(naturalH + padY * 2 + (scrolls ? arrowH * 2 : 0), maxH)
    x: level.ax + width > limitRight ? Math.max(0, level.altX - width) : level.ax
    y: level.up ? Math.max(0, level.ay - height) : Math.max(0, Math.min(level.ay, limitBottom - height))

    Column {
        id: measure
        visible: false
        Repeater { model: root.items; Body { required property var modelData; text: modelData.text ?? ""; font.pixelSize: root.big ? 17 : Theme.text } }
    }
    Column {
        id: hintMeasure
        visible: false
        Repeater { model: root.items; Body { required property var modelData; text: modelData.hint ? modelData.hint + "  " : ""; italic: true } }
    }

    // arrival: the slip unrolls downward
    property real reveal: 0
    NumberAnimation on reveal { id: unroll; from: 0; to: 1; duration: Theme.normal + (root.big ? 120 : 0); easing.type: Easing.OutQuart; running: true }
    readonly property var from: level.from
    onFromChanged: unroll.restart()

    // shadow on the desk
    Rectangle {
        x: 5; y: 8
        width: root.width
        height: root.height * root.reveal
        radius: 3
        color: Theme.alpha("#000000", 0.4)
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.8; blurMax: 24 }
    }

    Item {
        width: root.width
        height: root.height * root.reveal
        clip: true

        Parchment {
            width: root.width
            height: root.height
            age: root.big ? 0.5 : 0.35
        }
        // the rolled edge at the bottom while unrolling
        Rectangle {
            visible: root.reveal < 0.98
            y: root.height * root.reveal - 6
            width: root.width
            height: 6
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.pageDeep, 0) }
                GradientStop { position: 1; color: Theme.mix(Theme.pageDeep, Theme.ink, 0.3) }
            }
        }

        // ---------------------------------------------------------------- the contents heading
        Item {
            visible: root.big
            x: 0; y: root.padY
            width: root.width
            height: root.headH
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                text: "Contents"
                color: Theme.ink
                font.family: Theme.blackletter
                font.pixelSize: 34
            }
            GoldRule { anchors.horizontalCenter: parent.horizontalCenter; y: 46; width: parent.width - 60; color: Theme.alpha(Theme.inkDim, 0.7); ornament: "❦" }
        }

        Flickable {
            id: flick
            x: 8
            y: root.padY + root.headH + (root.scrolls ? root.arrowH : 0)
            width: root.width - 16
            height: root.height - root.padY * 2 - root.headH - (root.scrolls ? root.arrowH * 2 : 0)
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
                        readonly property int number: root.items.slice(0, index + 1).filter(it => !it.sep).length
                        width: rows.width
                        height: modelData.sep ? root.sepH : root.rowH

                        GoldRule {
                            visible: row.modelData.sep ?? false
                            anchors.centerIn: parent
                            width: parent.width - 40
                            color: Theme.alpha(Theme.inkDim, 0.55)
                            ornament: root.big ? "✦" : ""
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            visible: row.sel && !row.modelData.sep
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.alpha(Theme.gold, 0.34) }
                                GradientStop { position: 1; color: Theme.alpha(Theme.gold, 0.08) }
                            }
                        }
                        Text {
                            visible: row.sel && !row.modelData.sep
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "❧"
                            color: Theme.rubric
                            font.family: Theme.symbols
                            font.pixelSize: 12
                        }

                        // the contents: a red numeral; other slips: a check or lozenge for toggles
                        Text {
                            visible: root.big && !row.modelData.sep
                            x: 22
                            width: 40
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Theme.roman(row.number) + "."
                            color: Theme.rubric
                            font.family: Theme.display; font.weight: Font.DemiBold
                            font.pixelSize: 16
                        }
                        Text {
                            visible: !root.big && ((row.modelData.check || row.modelData.radio) === true)
                            x: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.radio ? "◆" : "✓"
                            color: Theme.rubric
                            font.family: Theme.symbols
                            font.pixelSize: row.modelData.radio ? 9 : 13
                        }
                        Item {
                            visible: !row.modelData.sep
                            x: root.big ? 74 : 38
                            width: parent.width - x - 30
                            height: parent.height
                            Body {
                                id: name
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: root.big && (row.modelData.sub_text ?? "") !== "" ? -8 : 0
                                width: Math.min(implicitWidth, parent.width)
                                elide: Text.ElideRight
                                text: row.modelData.text ?? ""
                                font.pixelSize: root.big ? 17 : Theme.text
                                strong: row.modelData.bold ?? false
                                color: !row.on ? Theme.alpha(Theme.inkDim, 0.6) : Theme.ink
                            }
                            // the leader, on the contents page
                            Text {
                                visible: root.big && !row.modelData.sub
                                anchors.baseline: name.baseline
                                x: name.width + 8
                                width: Math.max(0, parent.width - x - 4)
                                clip: true
                                text: "· ".repeat(90)
                                color: Theme.alpha(Theme.inkDim, 0.45)
                                font.family: Theme.body
                                font.pixelSize: Theme.small
                            }
                            Body {
                                visible: root.big && (row.modelData.sub_text ?? "") !== ""
                                anchors.top: name.bottom
                                anchors.topMargin: -2
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.sub_text ?? ""
                                italic: true
                                color: Theme.inkDim
                                font.pixelSize: Theme.small + 1
                            }
                        }
                        Body {
                            visible: (row.modelData.hint ?? "") !== ""
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.hint ?? ""
                            italic: true
                            color: Theme.inkDim
                            font.pixelSize: Theme.small + 1
                        }
                        Text {
                            visible: row.modelData.sub !== undefined
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            color: row.sel ? Theme.rubric : Theme.inkDim
                            font.family: Theme.body
                            font.pixelSize: 20
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
                Body {
                    visible: root.level.loading || root.items.length === 0
                    x: 38
                    height: root.rowH
                    verticalAlignment: Text.AlignVCenter
                    text: root.level.loading ? "turning the pages…" : "a blank page"
                    italic: true
                    color: Theme.inkDim
                }
            }
        }

        // scroll arrows (long menus)
        Repeater {
            model: root.scrolls ? [-1, 1] : []
            Item {
                required property int modelData
                x: 8
                y: modelData < 0 ? root.padY + root.headH : root.height - root.padY - root.arrowH
                width: root.width - 16
                height: root.arrowH
                Text { anchors.centerIn: parent; text: parent.modelData < 0 ? "▴" : "▾"; color: Theme.inkDim; font.family: Theme.symbols; font.pixelSize: 12 }
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
        return { left: x, right: x + width, y: y + padY + headH + (scrolls ? arrowH : 0) + top - flick.contentY };
    }
}
