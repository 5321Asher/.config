import QtQuick
import "../theme"

// A status tile: glyph in a ring, small-caps title, a mono status line. Click toggles; the
// chevron (when `more`) opens details.
Item {
    id: root

    property string glyph: ""
    property string title: ""
    property string status: ""
    property bool active: false
    property bool more: false
    signal clicked()
    signal details()

    implicitHeight: Theme.deckTile
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse ? Theme.alpha(Theme.hover, 0.9) : Theme.alpha(Theme.bgDark, 0.75)
        border.width: 1
        border.color: root.active ? Theme.alpha(Theme.brass, 0.9) : Theme.alpha(Theme.border, 0.9)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    // active: a brass bar down the left edge
    Rectangle {
        x: 0; y: 8
        width: 2
        height: parent.height - 16
        color: Theme.brassBright
        visible: root.active
    }
    Rectangle {
        id: ring
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 30; radius: 15
        color: root.active ? Theme.alpha(Theme.brassMuted, 0.9) : "transparent"
        border.width: 1
        border.color: root.active ? Theme.brassBright : Theme.alpha(Theme.brass, 0.6)
        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.active ? Theme.starlight : Theme.brass
            font.family: Theme.fontData
            font.pixelSize: 14
        }
    }
    Column {
        anchors.left: ring.right
        anchors.leftMargin: 10
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: -1
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: root.active ? Theme.brassBright : Theme.fg
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize + 1
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.status
            color: root.active ? Theme.phosphor : Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled) root.clicked()
    }
    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: root.more ? 22 : 0
        visible: root.more
        text: "\u{f0142}"
        color: moreMouse.containsMouse ? Theme.brassBright : Theme.dim
        font.family: Theme.fontData
        font.pixelSize: 16
        MouseArea {
            id: moreMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.details()
        }
    }
}
