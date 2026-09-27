import QtQuick

// Claude Code: left click opens it in a new terminal, right click shows account and usage info
Rectangle {
    id: root

    property bool active: false
    signal infoRequested

    implicitWidth: 30
    implicitHeight: Theme.barHeight - 10
    radius: 0
    color: active || mouse.containsMouse ? Theme.surface : "transparent"
    border.width: active ? 1 : 0
    border.color: Theme.accent

    ClaudeMark {
        anchors.centerIn: parent
        width: 16
        height: 16
        color: root.active || mouse.containsMouse ? Theme.accent : Theme.fg
        rotation: mouse.containsMouse ? 36 : 0

        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.infoRequested() : ClaudeStatus.launch()
    }
}
