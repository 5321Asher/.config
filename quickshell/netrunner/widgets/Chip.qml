import QtQuick
import "../theme"

// A switch tile for the helm: a name, what it's doing, and its switch; `more` adds a ▸ that
// opens the page it belongs to.
Item {
    id: root

    property string name: ""
    property string status: ""
    property bool checked: false
    property bool more: false
    signal toggled()
    signal details()

    implicitHeight: 52
    opacity: enabled ? 1 : 0.45

    Chamfer {
        anchors.fill: parent
        cut: 8
        corners: "tr"
        fill: root.checked ? Theme.alpha(Theme.red, 0.1) : Theme.alpha(Theme.bgDark, 0.5)
        stroke: root.checked ? Theme.alpha(Theme.red, 0.7) : Theme.line
    }
    Column {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 100
        spacing: 3
        Label { text: root.name; strong: true; color: root.checked ? Theme.bright : Theme.fg }
        Label { width: parent.width; elide: Text.ElideRight; text: root.status; color: root.checked ? Theme.cyan : Theme.dim; font.pixelSize: Theme.label - 1 }
    }
    Row {
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
