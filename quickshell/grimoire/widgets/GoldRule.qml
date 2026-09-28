import QtQuick
import "../theme"

// A horizontal rule: two hairlines that fade toward the ends, meeting at a lozenge (or a fleuron) in
// the middle. On parchment it's ink; on leather, gold.
Item {
    id: root

    property color color: Theme.gold
    property string ornament: "◆"        // "" for none, "❦", "✦"…
    readonly property real gapW: ornament ? orn.implicitWidth + 12 : 0

    implicitWidth: 200
    implicitHeight: 14

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: (parent.width - root.gapW) / 2
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.6; color: root.color }
            GradientStop { position: 1; color: root.color }
        }
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: (parent.width - root.gapW) / 2
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.color }
            GradientStop { position: 0.4; color: root.color }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Text {
        id: orn
        visible: root.ornament !== ""
        anchors.centerIn: parent
        text: root.ornament
        color: root.color
        font.family: Theme.symbols
        font.pixelSize: root.ornament === "◆" ? 8 : 13
    }
}
