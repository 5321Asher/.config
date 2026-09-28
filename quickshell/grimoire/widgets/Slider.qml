import QtQuick
import "../theme"

// A level: an inked groove filled with gold up to the value, and a small cut gem to drag. Click,
// drag or scroll. moved(v), v in 0..1.
Item {
    id: root

    property real value: 0
    property color color: Theme.gold
    property bool dark: false
    signal moved(real v)

    implicitWidth: 240
    implicitHeight: 18
    opacity: enabled ? 1 : 0.4

    readonly property real v: Math.max(0, Math.min(1, value))

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: root.dark ? Theme.alpha(Theme.fg, 0.14) : Theme.alpha(Theme.ink, 0.12)
        border.width: 1
        border.color: root.dark ? Theme.alpha(Theme.gold, 0.3) : Theme.alpha(Theme.inkDim, 0.35)
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(4, parent.width * root.v)
        height: 4
        radius: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.mix(root.color, Theme.ink, root.dark ? 0 : 0.35) }
            GradientStop { position: 1; color: root.color }
        }
    }
    // the gem
    Rectangle {
        x: parent.width * root.v - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 11
        height: 11
        rotation: 45
        color: root.color
        border.width: 1
        border.color: root.dark ? Theme.goldBright : Theme.ink
        Rectangle { x: 2; y: 2; width: 3; height: 3; color: Theme.alpha("#ffffff", 0.6) }
    }
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        function at(x) { root.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: e => at(e.x)
        onPositionChanged: e => { if (pressed) at(e.x); }
        onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.03 : -0.03))))
    }
}
