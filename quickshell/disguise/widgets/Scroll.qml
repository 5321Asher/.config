import QtQuick
import "../theme"

// A Flickable with Windows 11's scroll bar: a hairline that widens into a bar while you point at it.
// Put the content inside; contentHeight follows the content's height.
Flickable {
    id: root
    default property alias content: holder.data
    contentWidth: width
    contentHeight: holder.childrenRect.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 4000
    maximumFlickVelocity: 3000
    interactive: contentHeight > height

    Item { id: holder; width: root.width; height: childrenRect.height }

    Rectangle {
        id: bar
        parent: root
        visible: root.contentHeight > root.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 2
        readonly property real frac: root.height / Math.max(1, root.contentHeight)
        y: root.contentY / Math.max(1, root.contentHeight - root.height) * (root.height - height)
        width: barMouse.containsMouse || barMouse.pressed ? 6 : 2
        height: Math.max(30, root.height * frac)
        radius: width / 2
        color: Qt.alpha(Theme.text, 0.45)
        opacity: root.moving || barMouse.containsMouse ? 1 : 0.6
        Behavior on width { NumberAnimation { duration: Theme.fast } }
    }
    MouseArea {
        id: barMouse
        parent: root
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 12
        visible: bar.visible
        hoverEnabled: true
        property real grab: 0
        onPressed: e => grab = e.y - bar.y
        onPositionChanged: e => {
            if (!pressed) return;
            const room = root.height - bar.height;
            if (room > 0) root.contentY = Math.max(0, Math.min(1, (e.y - grab) / room)) * (root.contentHeight - root.height);
        }
    }
}
