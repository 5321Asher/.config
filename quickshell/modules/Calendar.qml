import QtQuick
import Quickshell

// Month view. Scroll or use the arrows to change month; "Today" jumps back.
Column {
    id: root

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    readonly property int cell: 40
    readonly property int gap: 4
    readonly property int gridWidth: cell * 7 + gap * 6
    readonly property bool onCurrentMonth: year === today.getFullYear() && month === today.getMonth()

    function reset() {
        const dir = new Date(year, month) < new Date(today.getFullYear(), today.getMonth()) ? 1 : -1;
        if (!onCurrentMonth)
            slide(dir);
        year = today.getFullYear();
        month = today.getMonth();
    }

    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
        slide(delta);
    }

    function slide(dir) {
        slideIn.from = 24 * dir;
        slideIn.restart();
    }

    // Monday-first grid of 42 dates covering the visible month
    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(year, month, 1 - offset + i));
        return out;
    }

    spacing: 16

    // Today, big
    Column {
        spacing: 2

        Text {
            text: Qt.formatDate(root.today, "dddd").toUpperCase()
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 3
            color: Theme.accent
        }

        Text {
            text: Qt.formatDate(root.today, "d MMMM")
            font.family: Theme.font
            font.pixelSize: 28
            font.bold: true
            color: Theme.fg
        }
    }

    Rectangle {
        width: root.gridWidth
        height: 1
        color: Theme.surface
    }

    // Month navigation
    Item {
        width: root.gridWidth
        height: 32

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM")
                font.family: Theme.font
                font.pixelSize: 17
                font.bold: true
                color: Theme.fg
            }

            Text {
                anchors.baseline: parent.children[0].baseline
                text: root.year
                font.family: Theme.font
                font.pixelSize: 17
                color: Theme.dim
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            NavButton {
                label: "Today"
                wide: true
                opacity: root.onCurrentMonth ? 0 : 1
                visible: opacity > 0
                onClicked: root.reset()

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            NavButton {
                label: ""
                onClicked: root.shift(-1)
            }

            NavButton {
                label: ""
                onClicked: root.shift(1)
            }
        }
    }

    Column {
        id: monthView
        spacing: 8

        NumberAnimation on x {
            id: slideIn
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }

        // Weekday names
        Row {
            spacing: root.gap

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                Text {
                    required property string modelData
                    required property int index
                    width: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.toUpperCase()
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1
                    color: index >= 5 ? Theme.accentMuted : Theme.dim
                }
            }
        }

        // Days
        Grid {
            columns: 7
            spacing: root.gap

            Repeater {
                model: root.days

                Rectangle {
                    id: day

                    required property var modelData
                    required property int index
                    readonly property bool inMonth: modelData.getMonth() === root.month
                    readonly property bool isToday: modelData.toDateString() === root.today.toDateString()
                    readonly property bool weekend: index % 7 >= 5

                    width: root.cell
                    height: root.cell - 4
                    radius: 0
                    color: isToday || (dayMouse.containsMouse && inMonth) ? Theme.surface : "transparent"
                    border.width: isToday || (dayMouse.containsMouse && inMonth) ? 1 : 0
                    border.color: isToday ? Theme.accent : Theme.border

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.bold: day.isToday
                        color: day.isToday ? Theme.accent
                             : !day.inMonth ? Theme.border
                             : day.weekend ? Theme.dim
                             : Theme.fg
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
    }

    component NavButton: Rectangle {
        property string label
        property bool wide: false
        signal clicked

        width: wide ? navText.implicitWidth + 20 : 30
        height: 30
        radius: 0
        color: navMouse.pressed ? Theme.border
             : navMouse.containsMouse ? Theme.surface
             : "transparent"
        border.width: 1
        border.color: navMouse.containsMouse ? Theme.accent : Theme.border

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            id: navText
            anchors.centerIn: parent
            text: parent.label
            font.family: Theme.font
            font.pixelSize: parent.wide ? 12 : 11
            font.bold: parent.wide
            color: navMouse.containsMouse ? Theme.accent : Theme.fg
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
