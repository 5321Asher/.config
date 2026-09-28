import QtQuick
import "../theme"

// A text input: a dark box with a red left edge while focused, mono text, a block caret.
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    signal accepted()
    signal edited()

    implicitWidth: 240
    implicitHeight: 30

    function focusField() { input.forceActiveFocus(); input.selectAll(); }

    Chamfer {
        anchors.fill: parent
        cut: Theme.chamferSmall
        corners: "br"
        fill: Theme.alpha(Theme.bgDark, 0.8)
        stroke: input.activeFocus ? Theme.alpha(Theme.red, 0.8) : Theme.line
    }
    Rectangle { width: 2; height: parent.height; color: input.activeFocus ? Theme.red : "transparent" }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.bright
        selectionColor: Theme.red
        selectedTextColor: Theme.onRed
        selectByMouse: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        font.family: Theme.mono
        font.pixelSize: Theme.data
        onAccepted: root.accepted()
        onTextEdited: root.edited()
        cursorDelegate: Rectangle {
            width: 8
            color: Theme.alpha(Theme.red, 0.8)
            visible: input.activeFocus
            SequentialAnimation on opacity { loops: Animation.Infinite; running: input.activeFocus
                NumberAnimation { to: 0; duration: 1 } PauseAnimation { duration: 450 }
                NumberAnimation { to: 1; duration: 1 } PauseAnimation { duration: 450 } }
        }
        Label {
            anchors.fill: parent
            visible: input.text === "" && root.placeholder !== ""
            text: root.placeholder
        }
    }
}
