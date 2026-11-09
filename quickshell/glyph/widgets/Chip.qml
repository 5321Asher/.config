import QtQuick
import "../theme"

// A quick-settings pill (Wi-Fi, Bluetooth…): a round glyph, the name and its state; white when on.
// Click toggles; the chevron (more) opens the details.
Item {
    id: root

    property string name: ""
    property string status: ""
    property string glyph: ""
    property bool checked: false
    property bool more: false
    signal toggled()
    signal details()

    implicitHeight: 76
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.fg : mouse.containsMouse ? Theme.s3 : Theme.s2
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Rectangle {
        id: disc
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 20
        height: width
        radius: width / 2
        color: root.checked ? Theme.ink : Theme.s3
        Icon { anchors.centerIn: parent; text: root.glyph || "\u{F0425}"; font.pixelSize: 22; color: root.checked ? Theme.fg : Theme.grey }
    }
    Column {
        anchors { left: disc.right; leftMargin: 14; right: chev.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.name
            font { family: Theme.ui; pixelSize: 17; weight: Font.Medium }
            color: root.checked ? Theme.ink : Theme.fg
        }
        Lb { width: parent.width; elide: Text.ElideRight; text: root.status; px: 10; color: root.checked ? Theme.ink : Theme.grey; opacity: root.checked ? 0.7 : 1 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
    Icon {
        id: chev
        visible: root.more
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        text: "\u{F0140}"
        font.pixelSize: 18
        color: root.checked ? Theme.ink : Theme.grey
        MouseArea { anchors.fill: parent; anchors.margins: -12; cursorShape: Qt.PointingHandCursor; onClicked: root.details() }
    }
}
