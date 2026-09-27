import QtQuick

// A slice of the cava spectrum: bars [start, start + count). Clickable.
Item {
    id: root

    property int start: 0
    property int count: Cava.bars / 2
    property int barWidth: 4
    property int maxHeight: 24

    signal clicked

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: root.count

            Rectangle {
                required property int index
                readonly property real value: Cava.values[root.start + index] ?? 0

                anchors.verticalCenter: parent.verticalCenter
                width: root.barWidth
                height: Math.max(2, value * root.maxHeight)
                radius: 0
                color: Theme.accent
                opacity: (mouse.containsMouse ? 0.3 : 0) + 0.35 + value * 0.5
            }
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
