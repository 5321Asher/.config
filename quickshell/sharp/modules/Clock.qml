import QtQuick
import Quickshell

Item {
    id: root

    property ShellScreen screen
    property alias open: popout.open

    implicitWidth: row.implicitWidth + 16
    implicitHeight: Theme.barHeight - 8

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.open || mouse.containsMouse ? Theme.surface : "transparent"

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.dim
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
            color: Theme.fg
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
    }

    Popout {
        id: popout
        screen: root.screen
        anchorItem: root
        onOpened: {
            calendar.today = clock.date;
            calendar.reset();
        }

        Calendar {
            id: calendar
        }
    }
}
