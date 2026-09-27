import QtQuick
import QtQuick.Effects
import "../theme"
import "../services"
import "../deck"

// The control deck's knob on the horizon. A phosphor dot shows unread transmissions.
Item {
    id: root

    width: Theme.surveyButton
    height: Theme.surveyButton

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.containsMouse || DeckState.open ? Theme.alpha(Theme.brassMuted, 0.9) : Theme.alpha(Theme.bgDark, 0.85)
        border.width: 1
        border.color: mouse.containsMouse || DeckState.open ? Theme.brassBright : Theme.brass
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 8
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 0.8
        border.color: Theme.alpha(Theme.brass, 0.45)
    }
    Text {
        anchors.centerIn: parent
        text: "\u{f0493}"
        color: mouse.containsMouse ? Theme.starlight : Theme.brass
        font.family: Theme.fontData
        font.pixelSize: Theme.surveyButton * 0.5
        rotation: DeckState.open ? 90 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
    }
    // unread transmissions
    Rectangle {
        visible: Transmissions.unread > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -1
        width: 8; height: 8; radius: 4
        color: Theme.phosphor
        border.width: 1
        border.color: Theme.bgDark
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: DeckState.open ? DeckState.open = false : DeckState.show(DeckState.page)
    }
    layer.enabled: mouse.containsMouse || DeckState.open
    layer.effect: MultiEffect {
        shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.6; shadowOpacity: 0.9
        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 14
    }
}
