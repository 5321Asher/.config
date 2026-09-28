import QtQuick
import "../theme"

// A button: a small plate with engraved caps. On a page: ink hairline, a wash of gold on hover;
// `primary` is gilded (gold leaf, the action you most likely want); `on` is pressed in (a toggle
// that's on: ink-filled). `dark` for leather (fg text, gold hairline).
Item {
    id: root

    property string text: ""
    property string glyph: ""
    property bool primary: false
    property bool on: false
    property bool dark: false
    property alias hovered: mouse.containsMouse
    signal clicked()
    signal rightClicked()

    readonly property color inkC: dark ? Theme.fg : Theme.ink
    implicitWidth: row.implicitWidth + 26
    implicitHeight: 28
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        border.width: 1
        border.color: root.primary ? Theme.goldDeep : root.on ? (root.dark ? Theme.gold : Theme.ink)
                    : mouse.containsMouse ? Theme.goldDeep : Theme.alpha(root.dark ? Theme.gold : Theme.inkDim, 0.6)
        gradient: Gradient {
            GradientStop { position: 0; color: root.primary ? Theme.goldBright : root.on ? Theme.alpha(root.dark ? Theme.gold : Theme.ink, 0.9)
                                                : mouse.containsMouse ? Theme.alpha(Theme.gold, 0.28) : "transparent" }
            GradientStop { position: 1; color: root.primary ? Theme.gold : root.on ? Theme.alpha(root.dark ? Theme.goldDeep : Theme.ink, 0.95)
                                                : mouse.containsMouse ? Theme.alpha(Theme.gold, 0.16) : "transparent" }
        }
        // a highlight along the top of gilded buttons
        Rectangle { visible: root.primary; x: 2; y: 1; width: parent.width - 4; height: 1; color: Theme.alpha("#ffffff", 0.45) }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Glyph {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: label.color
            font.pixelSize: 14
        }
        Caps {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            visible: root.text !== ""
            text: root.text
            strong: true
            color: root.primary ? Theme.mix(Theme.ink, Theme.goldDeep, 0.2) : root.on ? (root.dark ? Theme.onGold : Theme.page) : root.inkC
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
