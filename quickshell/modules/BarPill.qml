import QtQuick

// Small rounded status pill for the bar: optional icon or pulsing dot, plus text
Rectangle {
    id: root

    property color tint: Theme.accent
    property string icon
    property string text
    property bool pulse: false
    property bool dim: false
    signal clicked

    anchors.verticalCenter: parent?.verticalCenter
    implicitWidth: row.implicitWidth + 20
    implicitHeight: Theme.barHeight - 12
    radius: 0
    opacity: dim ? 0.6 : 1
    color: Qt.rgba(tint.r, tint.g, tint.b, mouse.containsMouse ? 0.3 : 0.18)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.pulse
            width: 8
            height: 8
            radius: 0
            color: root.tint

            SequentialAnimation on opacity {
                running: root.pulse && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 700 }
                NumberAnimation { to: 1; duration: 700 }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.font
            font.pixelSize: 13
            color: root.tint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
            color: root.tint
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
