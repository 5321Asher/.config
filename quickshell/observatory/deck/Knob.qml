import QtQuick
import QtQuick.Effects
import "../theme"

// A round brass instrument button with a Nerd Font glyph, and an optional small-caps label under it.
Item {
    id: root

    property string glyph: ""
    property string label: ""
    property bool active: false
    property bool danger: false
    property int size: Theme.deckKnob
    readonly property bool hovered: mouse.containsMouse
    signal clicked()

    implicitWidth: Math.max(size, lab.visible ? lab.implicitWidth : 0)
    implicitHeight: size + (lab.visible ? lab.implicitHeight + 4 : 0)
    opacity: enabled ? 1 : 0.4

    readonly property color ink: danger ? Theme.signal : Theme.brass

    Rectangle {
        id: face
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.size
        height: root.size
        radius: width / 2
        color: root.active ? Theme.alpha(root.danger ? Theme.signal : Theme.brassMuted, root.danger ? 0.35 : 0.95)
             : mouse.containsMouse ? Theme.alpha(Theme.hover, 0.95) : Theme.alpha(Theme.bgDark, 0.9)
        border.width: root.active || mouse.containsMouse ? 1.5 : 1
        border.color: root.active ? (root.danger ? Theme.signal : Theme.brassBright) : Theme.alpha(root.ink, mouse.containsMouse ? 1 : 0.7)
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3.5
            radius: width / 2
            color: "transparent"
            border.width: 0.7
            border.color: Theme.alpha(root.ink, 0.3)
        }
        Text {
            anchors.centerIn: parent
            text: root.glyph
            color: root.active ? Theme.starlight : root.ink
            font.family: Theme.fontData
            font.pixelSize: root.size * 0.44
        }
        layer.enabled: root.active
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: root.ink; shadowBlur: 0.6; shadowOpacity: 0.8
            shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 14
        }
    }
    Text {
        id: lab
        visible: root.label !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: face.bottom
        anchors.topMargin: 4
        text: root.label
        color: root.active ? Theme.brassBright : Theme.fg
        font.family: Theme.fontLabel
        font.pixelSize: Theme.labelSize - 1
        font.capitalization: Font.SmallCaps
        font.letterSpacing: Theme.labelSpacing
        font.weight: Font.DemiBold
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
