import QtQuick
import "../theme"

// A text box: sunken, white, black text, the selection in the highlight colour.
// `password` shows asterisks (98 did). Enter fires accepted().
Bevel {
    id: root

    property alias text: input.text
    property alias input: input
    property bool password: false
    property string placeholder: ""
    property bool readOnly: false
    signal accepted()
    signal edited()

    kind: "sunken"
    fill: enabled && !readOnly ? Theme.window : Theme.face
    implicitWidth: 200
    implicitHeight: Theme.field

    function focusField() { input.forceActiveFocus(); input.selectAll(); }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        enabled: root.enabled
        readOnly: root.readOnly
        color: enabled ? Theme.windowText : Theme.grayText
        selectionColor: Theme.select
        selectedTextColor: Theme.selectText
        selectByMouse: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "*"
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
        activeFocusOnTab: true
        onAccepted: root.accepted()
        onTextEdited: root.edited()

        // 98's caret: a plain black bar, blinking
        cursorDelegate: Rectangle {
            width: 1
            color: Theme.windowText
            visible: input.activeFocus && blink.on
            QtObject { id: blink; property bool on: true }
            Timer { running: input.activeFocus; repeat: true; interval: 530; onTriggered: blink.on = !blink.on }
        }

        Txt {
            anchors.fill: parent
            visible: input.text === "" && !input.activeFocus && root.placeholder !== ""
            text: root.placeholder
            color: Theme.grayText
        }
    }
}
