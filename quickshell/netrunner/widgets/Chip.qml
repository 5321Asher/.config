import QtQuick
import "../theme"

// A switch for the helm, drawn as a cyberware slot: a square socket with the thing's icon (lit when
// it's on), its name and what it's doing, the ON | OFF tabs; `more` adds a ▸ that opens its page.
Item {
    id: root

    property string name: ""
    property string status: ""
    property bool checked: false
    property bool more: false
    property string glyph: ({
        "wi-fi": "\u{f05a9}", "bluetooth": "\u{f00af}", "tailscale": "\u{f0582}", "do not disturb": "\u{f009b}",
        "idle // hold": "\u{f0176}", "lights follow": "\u{f03d8}",
    })[name] ?? "\u{f0425}"
    signal toggled()
    signal details()

    implicitHeight: 60
    opacity: enabled ? 1 : 0.45

    HoverHandler { id: hover }
    Chamfer {
        anchors.fill: parent
        cut: 9
        corners: "tr bl"
        fill: root.checked ? Theme.alpha(Theme.cyan, 0.09) : Theme.alpha(Theme.bgDark, 0.55)
        stroke: root.checked ? Theme.alpha(Theme.cyan, hover.hovered ? 1 : 0.65) : hover.hovered ? Theme.fg : Theme.line
    }
    Rectangle {           // the socket
        id: socket
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 40
        color: root.checked ? Theme.alpha(Theme.cyan, 0.16) : "transparent"
        border.width: 1; border.color: root.checked ? Theme.cyan : Theme.alpha(Theme.dim, 0.5)
        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.checked ? Theme.bright : Theme.dim
            font.family: Theme.mono; font.pixelSize: 20
        }
    }
    Column {
        x: socket.x + socket.width + 10
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - tabs.width - 22
        spacing: 3
        Text {
            width: parent.width; elide: Text.ElideRight
            text: root.name.toUpperCase()
            color: root.checked ? Theme.bright : Theme.fg
            font.family: Theme.condensed; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 1
        }
        Label { width: parent.width; elide: Text.ElideRight; text: root.status; color: root.checked ? Theme.cyan : Theme.dim; font.pixelSize: Theme.label - 1 }
    }
    Row {
        id: tabs
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Switch { anchors.verticalCenter: parent.verticalCenter; checked: root.checked; enabled: root.enabled; onToggled: root.toggled() }
        Text {
            visible: root.more
            anchors.verticalCenter: parent.verticalCenter
            text: "▸"
            color: Theme.dim
            font.pixelSize: 14
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: root.details() }
        }
    }
}
