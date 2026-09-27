import QtQuick

// Small round icon button, optionally with a text label
Rectangle {
    id: root

    property string icon
    property string label
    property color tint: Theme.fg
    property bool primary: false
    property bool spinning: false
    signal clicked

    implicitWidth: label ? row.implicitWidth + 20 : 30
    implicitHeight: 30
    radius: 0
    opacity: enabled ? 1 : 0.4
    color: primary ? Theme.surface : mouse.containsMouse ? Theme.border : Theme.hover
    border.width: primary ? 1 : 0
    border.color: Theme.accent
    scale: mouse.pressed ? 0.93 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 90 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.font
            font.pixelSize: 14
            color: root.primary ? Theme.accent : root.tint

            RotationAnimation on rotation {
                running: root.spinning
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
                onStopped: parent.rotation = 0
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            font.family: Theme.font
            font.pixelSize: 11
            font.bold: root.primary
            color: root.primary ? Theme.accent : root.tint
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
