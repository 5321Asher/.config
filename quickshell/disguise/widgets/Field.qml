import QtQuick
import "../theme"

// A WinUI text box: a white (dark: dim) box with an edge that's darker along the bottom, turning
// into a 2 px accent underline while you type. glyph = an icon at the right (the search box's).
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    property string glyph: ""
    property int radius: Theme.radius
    signal accepted()

    function focusField() { input.forceActiveFocus(); }

    implicitWidth: 240
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: input.activeFocus ? (Theme.dark ? "#1f1f1f" : "#ffffff") : mouse.containsMouse ? Theme.controlHover : (Theme.dark ? Qt.alpha("#ffffff", 0.06) : Theme.field)
        border.width: 1
        border.color: Theme.controlStroke
        clip: true
        // the underline
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: input.activeFocus ? 2 : 1
            color: input.activeFocus ? Theme.accent : Theme.strong
        }
    }
    TextInput {
        id: input
        anchors.fill: parent
        leftPadding: 11
        rightPadding: root.glyph ? 36 : 11
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.font
        font.pixelSize: Theme.body
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "●"
        clip: true
        onAccepted: root.accepted()
        Txt {
            anchors.fill: parent
            leftPadding: 11
            visible: input.text === "" && !input.preeditText
            text: root.placeholder
            level: 2
        }
    }
    Glyph {
        visible: root.glyph !== ""
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        g: root.glyph
        size: 14
        color: Theme.text2
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor
    }
}
