import QtQuick
import "../theme"

// A sheet of parchment: the page colour, its fibres and blotches (assets/paper.png), age at the
// margins and the odd foxing spot (assets/foxing.png, stretched), a deckle-dark edge.
Item {
    id: root

    property color color: Theme.page
    property real radius: 2
    property real texture: Theme.light ? 0.2 : 0.26
    property real age: 0.45            // how browned the margins are
    property bool edge: true

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.color
    }
    Image {
        anchors.fill: parent
        anchors.margins: 1
        source: Theme.assets + "paper.png"
        fillMode: Image.Tile
        opacity: root.texture
    }
    Image {
        anchors.fill: parent
        source: Theme.assets + "foxing.png"
        opacity: root.age
        smooth: true
    }
    Rectangle {
        visible: root.edge
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Theme.mix(Theme.pageDeep, Theme.ink, 0.35), 0.8)
    }
}
