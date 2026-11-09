import QtQuick
import "../theme"

// A toggle: a pill, white when on with the knob in ink; off is a dark pill with a grey knob.
Item {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 52
    implicitHeight: 30
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.fg : Theme.s2
        border { width: 1; color: root.checked ? Theme.fg : Theme.s3 }
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Rectangle {
            x: root.checked ? parent.width - width - 5 : 5
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 10
            height: width
            radius: width / 2
            color: root.checked ? Theme.ink : Theme.mute
            Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
