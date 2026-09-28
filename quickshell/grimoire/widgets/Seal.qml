import QtQuick
import QtQuick.Effects
import "../theme"

// A switch: a groove with a wax seal that slides along it. Off, the seal is cold and grey at the
// left; on, it's at the right in wax with a faint arcane glow, its rune pressed in.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 46
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 14
        radius: 7
        color: root.checked ? Theme.alpha(Theme.arcane, 0.22) : Theme.alpha(Theme.ink, 0.08)
        border.width: 1
        border.color: root.checked ? Theme.alpha(Theme.arcane, 0.8) : Theme.alpha(Theme.inkDim, 0.6)
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    Item {
        id: knob
        width: 22
        height: 22
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width + 1 : -1
        Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

        Rectangle {
            id: wax
            anchors.fill: parent
            radius: width / 2
            color: root.checked ? Theme.wax : Theme.mix(Theme.pageDeep, Theme.inkDim, 0.35)
            border.width: 2
            border.color: Qt.darker(color, 1.35)
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            layer.enabled: root.checked
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.arcane
                shadowBlur: 0.6
                shadowOpacity: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 12
            }
        }
        Text {
            anchors.centerIn: parent
            text: "ᛟ"
            color: Qt.lighter(wax.color, root.checked ? 1.7 : 1.25)
            font.family: Theme.runic
            font.pixelSize: 12
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
