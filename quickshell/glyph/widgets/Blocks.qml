import QtQuick
import "../theme"

// A short meter of dots (old Blocks API): `count` dots, the fraction `value` lit.
Row {
    id: root

    property real value: 0
    property int count: 5
    property int blockWidth: 6
    property int blockHeight: 6
    property color color: Theme.fg
    property color off: Theme.s3

    spacing: 4
    Repeater {
        model: root.count
        Rectangle {
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            width: root.blockWidth
            height: root.blockHeight
            radius: Math.min(width, height) / 2
            color: index < Math.round(Math.max(0, Math.min(1, root.value)) * root.count) ? root.color : root.off
        }
    }
}
