import QtQuick
import "../theme"

// A panel: translucent dark, cut at two corners, hairline edge, and a header line: the title in
// white tracked caps, a Japanese accent in cyan, and optional text on the right ("1/3 CLEARED").
// `brackets` adds the red corner ticks the SYS.DIAG panel has. Children go under the header.
Item {
    id: root

    property string title: ""
    property string jp: ""
    property string trailing: ""
    property color trailingColor: Theme.dim
    property bool brackets: false
    property bool big: false                // SYS.DIAG-sized title
    property real contentTop: header.y + header.height + 12
    default property alias content: body.data
    readonly property alias body: body

    Chamfer {
        anchors.fill: parent
        cut: Theme.chamfer
        corners: "tr bl"
        fill: Theme.panel
        stroke: Theme.alpha(Theme.line, 0.9)
    }

    // red corner ticks (top-left and bottom-right)
    Item {
        visible: root.brackets
        anchors.fill: parent
        Rectangle { x: 6; y: 6; width: 10; height: 2; color: Theme.red }
        Rectangle { x: 6; y: 6; width: 2; height: 10; color: Theme.red }
        Rectangle { x: parent.width - 16; y: parent.height - 8; width: 10; height: 2; color: Theme.red }
        Rectangle { x: parent.width - 8; y: parent.height - 16; width: 2; height: 10; color: Theme.red }
    }

    Row {
        id: header
        x: Theme.pad
        y: root.big ? 14 : 12
        spacing: 8
        visible: root.title !== ""
        Text {
            visible: root.big
            anchors.baseline: jpText.baseline
            text: root.title
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: Theme.title
            font.weight: Font.Bold
        }
        Label {
            visible: !root.big
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            strong: true
            color: Theme.bright
        }
        Jp { id: jpText; anchors.verticalCenter: parent.verticalCenter; visible: text !== ""; text: root.jp }
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        y: header.y
        height: header.height
        visible: text !== ""
        text: root.trailing
        color: root.trailingColor
    }

    Item {
        id: body
        x: Theme.pad
        y: root.title !== "" ? root.contentTop : Theme.pad
        width: root.width - Theme.pad * 2
        height: root.height - y - Theme.pad
    }
}
