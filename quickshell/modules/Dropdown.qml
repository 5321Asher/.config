import QtQuick
import QtQuick.Layouts

// Inline dropdown: a button showing the current choice that expands into a list below it.
// `options` is a list of { label, value }.
ColumnLayout {
    id: root

    property var options: []
    property var value
    property string placeholder: "Select"
    property bool expanded: false
    property int maxVisible: 6

    signal picked(var value)

    readonly property var currentOption: options.find(o => o.value === value) ?? null

    Layout.fillWidth: true
    spacing: 4

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36
        radius: 0
        opacity: root.enabled ? 1 : 0.4
        color: headMouse.containsMouse || root.expanded ? Theme.hover : Theme.bgDark
        border.width: 1
        border.color: root.expanded ? Theme.accent : Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Text {
                Layout.fillWidth: true
                text: root.currentOption?.label ?? root.placeholder
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                color: root.currentOption ? Theme.fg : Theme.dim
            }

            Text {
                text: String.fromCodePoint(0xF0140)
                font.family: Theme.font
                font.pixelSize: 14
                color: Theme.dim
                rotation: root.expanded ? 180 : 0

                Behavior on rotation { NumberAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: headMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        Layout.fillWidth: true
        visible: root.expanded
        implicitHeight: Math.min(root.options.length, root.maxVisible) * 32 + 8
        radius: 0
        color: Theme.bgDark
        border.width: 1
        border.color: Theme.accent
        clip: true

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: 4
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            delegate: Rectangle {
                required property var modelData

                readonly property bool current: modelData.value === root.value

                width: list.width
                height: 32
                radius: 0
                color: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                     : optMouse.containsMouse ? Theme.hover : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: parent.current
                    color: parent.current ? Theme.accent : Theme.fg
                }

                MouseArea {
                    id: optMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.expanded = false;
                        root.picked(parent.modelData.value);
                    }
                }
            }
        }
    }
}
