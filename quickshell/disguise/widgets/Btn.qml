import QtQuick
import "../theme"

// A WinUI button. kind: "standard" (a light fill, hairline edge darker along the bottom),
// "accent" (the default button), "subtle" (transparent until pointed at). Text and/or a glyph.
Item {
    id: root

    property string kind: "standard"
    property string text: ""
    property string glyph: ""
    property int glyphSize: 16
    property bool checked: false          // subtle buttons stay lit while checked
    property int padding: 12
    property int radius: Theme.radius
    property alias hovered: mouse.containsMouse
    readonly property bool down: mouse.pressed
    property color textColor: kind === "accent" ? Theme.accentText : Theme.text
    signal clicked()
    signal rightClicked()

    implicitHeight: Theme.controlHeight
    implicitWidth: Math.max(kind === "subtle" && text === "" ? Theme.controlHeight : 96, row.implicitWidth + padding * 2)
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.kind === "accent" ? (root.down ? Theme.accentPressed : root.hovered ? Theme.accentHover : Theme.accent)
             : root.kind === "subtle" ? (root.down ? Theme.subtle2 : (root.hovered || root.checked) ? Theme.subtle : "transparent")
             : (root.down ? Theme.controlPressed : root.hovered ? Theme.controlHover : Theme.control)
        border.width: root.kind === "subtle" ? 0 : 1
        border.color: root.kind === "accent" ? Qt.alpha("#ffffff", 0.08) : Theme.controlStroke
        // the darker bottom edge
        Rectangle {
            visible: root.kind !== "subtle" && !root.down
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: root.radius }
            anchors.rightMargin: root.radius
            height: 1
            color: root.kind === "accent" ? Qt.alpha("#000000", 0.25) : Theme.controlStrokeBottom
        }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Glyph {
            visible: root.glyph !== ""
            g: root.glyph
            size: root.glyphSize
            color: root.textColor
            opacity: root.down && root.kind !== "accent" ? 0.7 : 1
            anchors.verticalCenter: parent.verticalCenter
        }
        Txt {
            visible: root.text !== ""
            text: root.text
            color: root.textColor
            opacity: root.down ? 0.8 : 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
