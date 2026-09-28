import QtQuick
import "../theme"

// 98's progress bar: sunken, filled with separate blocks in the highlight colour.
// `smooth` fills it solid instead (meters). `color` overrides the blocks' colour.
Bevel {
    id: root

    property real value: 0              // 0..1
    property bool smooth: false
    property color color: Theme.select
    property string label: ""           // centred text (smooth bars only)

    kind: "status"
    fill: Theme.face
    implicitWidth: 200
    implicitHeight: 20

    readonly property int blockW: Math.round((height - 4) * 0.7)
    readonly property int inner: width - 4

    Item {
        anchors.fill: parent
        anchors.margins: 2
        clip: true

        Rectangle {
            visible: root.smooth
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            color: root.color
        }
        Row {
            visible: !root.smooth
            spacing: 2
            x: 1
            y: 1
            Repeater {
                model: Math.ceil(Math.max(0, Math.min(1, root.value)) * root.inner / (root.blockW + 2))
                Rectangle { width: root.blockW; height: root.height - 6; color: root.color }
            }
        }
        Txt {
            anchors.centerIn: parent
            visible: root.label !== ""
            text: root.label
        }
    }
}
