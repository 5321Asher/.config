import QtQuick
import "../theme"

// A section of a page, set like a manuscript: its first letter in blackletter red ink (a rubric),
// the rest in uncials, a fading rule with a fleuron under it, optional italic text at the right;
// children stack below.
Column {
    id: root

    property string title: ""
    property string trailing: ""
    property color trailingColor: Theme.inkDim
    default property alias content: body.data

    width: parent ? parent.width : 400
    spacing: 4

    Item {
        width: parent.width
        height: head.implicitHeight - 6
        Row {
            id: head
            y: -6
            spacing: 1
            Text {
                id: cap
                text: root.title.charAt(0).toUpperCase()
                color: Theme.rubric
                font.family: Theme.blackletter
                font.pixelSize: 30
            }
            Text {
                id: rest
                anchors.baseline: cap.baseline
                text: root.title.slice(1)
                color: Theme.ink
                font.family: Theme.display; font.weight: Font.DemiBold
                font.pixelSize: 17
            }
        }
        Body {
            anchors.right: parent.right
            y: head.y + cap.baselineOffset - baselineOffset
            text: root.trailing
            italic: true
            color: root.trailingColor
            font.pixelSize: Theme.small + 1
            width: Math.min(implicitWidth, parent.width * 0.6)
            elide: Text.ElideLeft
            horizontalAlignment: Text.AlignRight
        }
    }
    GoldRule { width: parent.width; color: Theme.alpha(Theme.inkDim, 0.55); ornament: "" }
    Column {
        id: body
        width: parent.width
        spacing: 8
    }
}
