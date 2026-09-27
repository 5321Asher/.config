import QtQuick

// On/off switch
Rectangle {
    id: root

    property bool checked
    signal toggled

    implicitWidth: 44
    implicitHeight: 24
    radius: 0
    opacity: enabled ? 1 : 0.4
    color: checked ? Theme.surface : Theme.bgDark
    border.width: 1
    border.color: checked ? Theme.accent : Theme.border

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        x: root.checked ? root.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 0
        color: root.checked ? Theme.accent : Theme.dim

        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
