import QtQuick

// Bar button that toggles the main side panel
Rectangle {
    id: root

    property bool active: false
    signal clicked

    implicitWidth: 36
    implicitHeight: Theme.barHeight - 8
    radius: 0
    color: active || mouse.containsMouse ? Theme.surface : "transparent"
    border.width: active ? 1 : 0
    border.color: Theme.accent

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: ""
        font.family: Theme.font
        font.pixelSize: 15
        color: root.active ? Theme.accent : Theme.fg
        rotation: root.active ? 90 : 0

        Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    // Unread notifications
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        width: 7
        height: 7
        radius: 0
        color: Theme.accent
        scale: Notifs.unread ? 1 : 0

        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
