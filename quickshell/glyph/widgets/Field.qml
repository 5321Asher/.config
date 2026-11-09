import QtQuick
import "../theme"

// A text field: a dark pill, Space Grotesk, the caret red (it's the live thing while you type).
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    property string glyph: ""
    signal accepted()
    signal edited()
    signal keyPressed(var event)       // set event.accepted to take the key

    implicitWidth: 300
    implicitHeight: 52

    function focusField() { input.forceActiveFocus(); input.selectAll(); }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.s2
        border { width: 1; color: input.activeFocus ? Theme.s3 : "transparent" }
    }
    Icon { id: g; visible: root.glyph !== ""; x: 20; anchors.verticalCenter: parent.verticalCenter; text: root.glyph; color: Theme.grey; font.pixelSize: 20 }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: root.glyph !== "" ? 54 : 22; rightMargin: 22 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.fg
        selectionColor: Theme.s3
        selectedTextColor: Theme.fg
        selectByMouse: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "●"
        font { family: Theme.ui; pixelSize: Math.round(root.height * 0.36) }
        onAccepted: root.accepted()
        onTextEdited: root.edited()
        Keys.onPressed: e => root.keyPressed(e)
        cursorDelegate: Rectangle {
            width: 2
            color: Theme.red
            visible: input.activeFocus
            Timer { running: input.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 4
            visible: input.text === "" && root.placeholder !== ""
            text: root.placeholder
            font: input.font
            color: Theme.mute
        }
    }
}
