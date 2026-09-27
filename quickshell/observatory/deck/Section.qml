import QtQuick
import "../theme"

// A deck section: small-caps brass title, a hairline running to the right, optional trailing
// readout; content stacks underneath.
Column {
    id: root

    property string title: ""
    property string trailing: ""
    property color trailingColor: Theme.dim
    default property alias content: body.data

    width: parent ? parent.width : 400
    spacing: 10

    Item {
        width: parent.width
        height: head.implicitHeight
        visible: root.title !== ""

        Text {
            id: head
            text: root.title
            color: Theme.brass
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize + 1
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing * 1.4
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.left: head.right
            anchors.leftMargin: 10
            anchors.right: tail.left
            anchors.rightMargin: tail.text ? 10 : 0
            anchors.verticalCenter: head.verticalCenter
            height: 1
            color: Theme.alpha(Theme.brass, 0.25)
        }
        Text {
            id: tail
            anchors.right: parent.right
            anchors.verticalCenter: head.verticalCenter
            text: root.trailing
            color: root.trailingColor
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: 8
    }
}
