import QtQuick
import "../theme"

// A group box: an etched frame with its caption set into the top edge. Children stack in a Column.
Item {
    id: root

    property string title: ""
    property int spacing: Theme.gap
    default property alias content: col.data

    implicitWidth: col.implicitWidth + Theme.pad * 2
    implicitHeight: col.implicitHeight + Theme.pad + 22

    Bevel {
        kind: "etched"
        anchors.fill: parent
        anchors.topMargin: 9
    }
    // the caption, on the face colour so it cuts the line
    Rectangle {
        visible: root.title !== ""
        x: 8
        width: cap.implicitWidth + 6
        height: 18
        color: Theme.face
        Txt { id: cap; x: 3; height: 18; text: root.title }
    }
    Column {
        id: col
        x: Theme.pad
        y: 24
        width: root.width - Theme.pad * 2
        spacing: root.spacing
    }
}
