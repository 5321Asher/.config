import QtQuick
import QtQuick.Effects
import "../theme"
import "../widgets"
import "../launcher"

// The back of a drawn card, opened out: the same leather and gilt as its face, its numeral and name at
// the head (and the way you came, if you have gone deeper), and set on the leather the card menu:
// a gilt numeral, the entry, a line of italic under it; a wax dot marks the one in use, a › one that
// opens further. Going deeper slides the next list in.
Item {
    id: root

    property var card: ({})
    property bool open: false
    readonly property var level: ContentsState.stack[ContentsState.stack.length - 1] ?? ({ items: [], loading: true, sel: 0 })
    readonly property int depth: ContentsState.stack.length
    // how tall the card must be to hold its head and every entry (Arcana sizes the card from this)
    readonly property real needed: head.y + head.height + 26 + 28 + list.contentHeight + 46

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: -26
        anchors.leftMargin: 4
        anchors.rightMargin: -10
        radius: 16
        color: Qt.alpha("#000000", 0.6)
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
    }
    // the card's back: the same leather and gilt as its face
    Cover {
        id: back
        anchors.fill: parent
        radius: 14
        bevel: 10
        wear: 0.5
        seed: 0.29
        color: Theme.leather
        light: Qt.vector3d(width * 0.25, -height * 0.2, 700)
        lightPower: 1.2
        ambient: 0.6
        lightColor: Theme.mix(Theme.flame, "#ffffff", 0.55)
        Rectangle { anchors.fill: parent; anchors.margins: 9; radius: 8; color: "transparent"; border.width: 1.3; border.color: back.gilt }
        Rectangle { anchors.fill: parent; anchors.margins: 13; radius: 6; color: "transparent"; border.width: 0.8; border.color: back.gilt }
    }

    Item {
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        // ------------------------------------------------------------ the head
        Column {
            id: head
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            spacing: 2
            Caps {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.card.numeral ?? ""
                color: Theme.alpha(Theme.gold, 0.8)
                font.pixelSize: 12
                font.letterSpacing: 4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.level.title ?? root.card.title ?? ""
                color: Theme.goldBright
                font.family: Theme.caps
                font.pixelSize: 24
                font.weight: Font.Bold
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
            }
            Body {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.depth > 1 ? "‹ " + ContentsState.stack.slice(0, -1).map(l => l.title).join(" · ") : (root.card.sub_text ?? "")
                italic: true
                color: Theme.alpha(Theme.fg, 0.6)
                font.pixelSize: 14
                MouseArea {
                    anchors.fill: parent
                    enabled: root.depth > 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ContentsState.back()
                }
            }
        }

        // ------------------------------------------------------------ the leaf
        // the entries, set straight onto the card's leather (the same leather and gilt as its face)
        GoldRule { x: 34; y: head.y + head.height + 8; width: parent.width - 68; color: Theme.alpha(Theme.gold, 0.6); ornament: "◆" }
        Item {
            id: leaf
            anchors.fill: parent
            anchors.margins: 22
            anchors.topMargin: head.y + head.height + 26
            anchors.bottomMargin: 46

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 14
                clip: true
                model: root.level.items
                currentIndex: ContentsState.row
                highlightFollowsCurrentItem: true
                highlightMoveDuration: Theme.fast
                boundsBehavior: Flickable.StopAtBounds
                // scrolls only when there really are more entries than room
                interactive: contentHeight > height + 1
                spacing: 2
                // going deeper slides the next list in
                property int shownDepth: root.depth
                onModelChanged: if (root.depth !== shownDepth) { shownDepth = root.depth; slide.restart(); }
                NumberAnimation { id: slide; target: list; property: "slideX"; from: 24; to: 0; duration: Theme.normal; easing.type: Theme.easing }
                property real slideX: 0
                transform: Translate { x: list.slideX }

                highlight: Item {
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.alpha(Theme.gold, 0.18) }
                            GradientStop { position: 1; color: Theme.alpha(Theme.gold, 0.02) }
                        }
                    }
                    Rectangle { width: 2; height: parent.height - 12; anchors.verticalCenter: parent.verticalCenter; color: Theme.gold }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: (modelData.sub_text ?? "") !== "" ? 54 : 42

                    Body {
                        x: 12
                        width: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.roman(row.index + 1).toLowerCase() + "."
                        italic: true
                        color: Theme.alpha(Theme.gold, 0.85)
                        font.pixelSize: 14
                    }
                    Column {
                        x: 50
                        width: parent.width - x - 36
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Body {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.text ?? ""
                            font.pixelSize: 18
                            color: row.ListView.isCurrentItem ? Theme.goldBright : Theme.fg
                        }
                        Body {
                            visible: text !== ""
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.sub_text ?? ""
                            italic: true
                            color: Theme.alpha(Theme.dim, 0.85)
                            font.pixelSize: 13
                        }
                    }
                    // in use: a dab of wax; opens further: ›
                    Rectangle {
                        visible: row.modelData.check === true
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: Theme.wax
                        border.width: 1
                        border.color: Qt.darker(Theme.wax, 1.4)
                    }
                    Body {
                        visible: !!row.modelData.sub
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.alpha(Theme.dim, 0.85)
                        font.pixelSize: 22
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: ContentsState.setSel(row.index)
                        onClicked: ContentsState.choose(row.index)
                    }
                }
            }
            Body {
                anchors.centerIn: parent
                visible: root.level.loading || root.level.items.length === 0
                text: root.level.loading ? "the cards are read…" : "nothing here"
                italic: true
                color: Theme.alpha(Theme.dim, 0.85)
            }
        }

        Caps {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            text: "↑ ↓  choose   ·   enter   ·   esc  back"
            color: Theme.alpha(Theme.gold, 0.55)
            font.pixelSize: 10
            font.letterSpacing: 3
        }
    }
}
