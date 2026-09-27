import QtQuick
import "../theme"

// A text button: small-caps label on a thin brass-edged plate.
Item {
    id: root

    property string text: ""
    property string glyph: ""
    property bool danger: false
    property bool primary: false
    signal clicked()

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4

    readonly property color ink: danger ? Theme.signal : Theme.brass

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: mouse.containsMouse ? Theme.alpha(root.danger ? Theme.signal : Theme.brassMuted, root.danger ? 0.25 : 0.7)
             : root.primary ? Theme.alpha(Theme.brassMuted, 0.45) : Theme.alpha(Theme.bgDark, 0.7)
        border.width: 1
        border.color: Theme.alpha(root.ink, mouse.containsMouse || root.primary ? 0.95 : 0.55)
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.ink
            font.family: Theme.fontData
            font.pixelSize: 13
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: mouse.containsMouse ? Theme.starlight : root.danger ? Theme.signal : Theme.fg
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
