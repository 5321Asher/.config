import QtQuick

// Single-line input with placeholder, optional icon and password reveal
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder
    property string icon
    property bool password: false
    property bool revealed: false
    signal accepted

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 36
    radius: 0
    color: Theme.bgDark
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border

    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        id: iconText
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon !== ""
        text: root.icon
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.dim
    }

    TextInput {
        id: input

        anchors.left: iconText.visible ? iconText.right : parent.left
        anchors.leftMargin: iconText.visible ? 8 : 12
        anchors.right: reveal.visible ? reveal.left : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        font.family: Theme.font
        font.pixelSize: 12
        color: Theme.fg
        selectionColor: Theme.accentMuted
        selectedTextColor: Theme.fg
        echoMode: root.password && !root.revealed ? TextInput.Password : TextInput.Normal
        onAccepted: root.accepted()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: !input.text && !input.activeFocus
            text: root.placeholder
            font: input.font
            color: Theme.border
        }
    }

    Text {
        id: reveal
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: root.password
        text: String.fromCodePoint(root.revealed ? 0xF0209 : 0xF0208)
        font.family: Theme.font
        font.pixelSize: 14
        color: Theme.dim

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.revealed = !root.revealed
        }
    }
}
