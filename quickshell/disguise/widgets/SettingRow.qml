import QtQuick
import "../theme"

// One of Settings' rows: a card with an icon, a title and a description on the left and a control
// (whatever you put inside) on the right. clickable: the whole card lights up and a chevron shows.
Item {
    id: root

    default property alias control: slot.data
    property string glyph: ""
    property string icon: ""            // a theme icon (an app's) instead of a glyph
    property string title: ""
    property string subtitle: ""
    property bool clickable: false
    property bool first: true
    property bool last: true
    property string chevron: ""
    signal clicked()

    implicitWidth: 600
    implicitHeight: Math.max(subtitle ? 68 : 56, texts.implicitHeight + 24)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: root.clickable && mouse.pressed ? Theme.controlPressed : root.clickable && mouse.containsMouse ? Theme.cardHover : Theme.card
        border.width: 1
        border.color: Theme.cardStroke
    }
    Glyph {
        id: icon
        visible: root.glyph !== ""
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        g: root.glyph
        size: 20
    }
    AppIcon {
        visible: root.icon !== ""
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        size: 24
        name: root.icon
    }
    Column {
        id: texts
        x: root.glyph || root.icon ? 56 : 18
        width: slot.x - x - 16
        anchors.verticalCenter: parent.verticalCenter
        Txt { width: parent.width; text: root.title; wrapMode: Text.Wrap; elide: Text.ElideNone }
        Txt { visible: root.subtitle !== ""; width: parent.width; text: root.subtitle; size: Theme.caption; level: 2; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        onClicked: root.clicked()
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: root.clickable ? 44 : 18
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
    Glyph {
        visible: root.clickable
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        g: root.chevron
        size: 12
        color: Theme.text2
    }
}
