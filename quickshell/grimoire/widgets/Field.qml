import QtQuick
import "../theme"

// A text field written on the page: an inked line under the words, which turns red while you
// write; the placeholder in italic; a thin red quill for the caret.
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    property bool dark: false
    signal accepted()
    signal edited()

    implicitWidth: 240
    implicitHeight: 32

    function focusField() { input.forceActiveFocus(); input.selectAll(); }

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: root.dark ? Theme.alpha(Theme.leatherDark, 0.6) : Theme.alpha("#ffffff", input.activeFocus ? 0.22 : 0.12)
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: input.activeFocus ? 2 : 1
        color: input.activeFocus ? (root.dark ? Theme.gold : Theme.rubric) : Theme.alpha(root.dark ? Theme.gold : Theme.inkDim, 0.7)
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: root.dark ? Theme.goldBright : Theme.ink
        selectionColor: Theme.alpha(Theme.gold, 0.5)
        selectedTextColor: root.dark ? Theme.fg : Theme.ink
        selectByMouse: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "✦"
        font.family: Theme.body
        font.pixelSize: Theme.text
        onAccepted: root.accepted()
        onTextEdited: root.edited()
        cursorDelegate: Rectangle {
            width: 2
            color: root.dark ? Theme.gold : Theme.rubric
            visible: input.activeFocus
            SequentialAnimation on opacity { loops: Animation.Infinite; running: input.activeFocus
                NumberAnimation { to: 0.15; duration: 520; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine } }
        }
        Body {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && root.placeholder !== ""
            text: root.placeholder
            italic: true
            elide: Text.ElideRight
            color: root.dark ? Theme.dim : Theme.alpha(Theme.inkDim, 0.85)
        }
    }
}
