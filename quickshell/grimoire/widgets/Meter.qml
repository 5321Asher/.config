import QtQuick
import "../theme"

// A filled bar in an inked frame (memory, storage, limits): gold by default, red past `hot`.
Item {
    id: root

    property real value: 0
    property color color: Theme.gold
    property real hot: 2                // above this the fill turns red ink
    property bool dark: false

    implicitWidth: 200
    implicitHeight: 8

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.dark ? Theme.alpha(Theme.fg, 0.1) : Theme.alpha(Theme.ink, 0.08)
        border.width: 1
        border.color: root.dark ? Theme.alpha(Theme.gold, 0.35) : Theme.alpha(Theme.inkDim, 0.4)
    }
    Rectangle {
        id: fill
        x: 1; y: 1
        height: parent.height - 2
        width: Math.max(0, (parent.width - 2) * Math.max(0, Math.min(1, root.value)))
        radius: height / 2
        readonly property color c: root.value > root.hot ? Theme.danger : root.color
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.mix(fill.c, Theme.ink, root.dark ? 0.1 : 0.3) }
            GradientStop { position: 1; color: fill.c }
        }
        Behavior on width { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
    }
}
