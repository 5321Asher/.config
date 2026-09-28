import QtQuick
import "../theme"

// A charm: one of the Sanctum's switches as a small card on the page: its name in uncials, how it
// stands in italic, a wax-seal switch, and (with `more`) a › that turns to its own chapter.
Item {
    id: root

    property string name: ""
    property string status: ""
    property bool checked: false
    property bool more: false
    signal toggled()
    signal details()

    implicitWidth: 200
    implicitHeight: 62
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.checked ? Theme.alpha(Theme.arcane, 0.1) : Theme.alpha("#ffffff", 0.12)
        border.width: 1
        border.color: root.checked ? Theme.alpha(Theme.arcane, 0.55) : Theme.alpha(Theme.inkDim, 0.4)
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    MouseArea { anchors.fill: parent; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
    Column {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 70
        spacing: 1
        Text { width: parent.width; elide: Text.ElideRight; text: root.name; color: Theme.ink; font.family: Theme.uncial; font.pixelSize: 15 }
        Body { width: parent.width; elide: Text.ElideRight; text: root.status; italic: true; color: Theme.inkDim; font.pixelSize: 13 }
    }
    Seal {
        anchors.right: parent.right
        anchors.rightMargin: root.more ? 30 : 12
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        enabled: root.enabled
        onToggled: root.toggled()
    }
    Text {
        visible: root.more
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        color: Theme.inkDim
        font.family: Theme.body
        font.pixelSize: 22
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.details() }
    }
}
