import QtQuick
import Quickshell
import Quickshell.Widgets
import "../theme"

// One row in a deck list: glyph or icon, title and subtitle, trailing readout; clickable.
Item {
    id: root

    property string glyph: ""
    property string icon: ""            // a theme icon name or a path/url
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property color trailingColor: Theme.dim
    property bool active: false
    property bool clickable: true
    default property alias extra: tail.data
    signal clicked()

    implicitHeight: Math.max(36, texts.implicitHeight + 12)
    width: parent ? parent.width : 300

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.active ? Theme.alpha(Theme.brassMuted, 0.45)
             : mouse.containsMouse && root.clickable ? Theme.alpha(Theme.hover, 0.8) : "transparent"
        border.width: root.active ? 1 : 0
        border.color: Theme.alpha(Theme.brass, 0.6)
    }
    Item {
        id: lead
        x: 8
        width: 22
        height: parent.height
        Text {
            anchors.centerIn: parent
            visible: root.glyph !== "" && !img.visible
            text: root.glyph
            color: root.active ? Theme.brassBright : Theme.brass
            font.family: Theme.fontData
            font.pixelSize: 15
        }
        IconImage {
            id: img
            anchors.centerIn: parent
            readonly property string src: root.icon.startsWith("/") ? "file://" + root.icon
                : root.icon.includes("://") ? root.icon
                : root.icon !== "" && Quickshell.hasThemeIcon(root.icon) ? Quickshell.iconPath(root.icon) : ""
            visible: src !== ""
            implicitSize: 20
            source: src
        }
    }
    Column {
        id: texts
        anchors.left: lead.right
        anchors.leftMargin: 10
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: root.active ? Theme.brassBright : Theme.fg
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSize
        }
        Text {
            width: parent.width
            visible: text !== ""
            elide: Text.ElideRight
            text: root.subtitle
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailing !== ""
            text: root.trailing
            color: root.trailingColor
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }
}
