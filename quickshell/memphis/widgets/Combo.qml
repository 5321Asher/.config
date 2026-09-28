import QtQuick
import "../theme"

// A drop-down list box: a sunken field with the choice and a button with an arrow; the list opens
// under it (inside the same window, over whatever is below). chosen(index) when one is picked.
Item {
    id: root

    property var model: []                      // strings, or objects shown through textOf
    property var textOf: item => String(item)
    property int currentIndex: -1
    property string placeholder: ""
    property int maxRows: 8
    property bool open: false
    signal chosen(int index)

    implicitWidth: 220
    implicitHeight: Theme.field
    z: open ? 100 : 0
    activeFocusOnTab: true

    Keys.onDownPressed: if (currentIndex < model.length - 1) chosen(currentIndex + 1)
    Keys.onUpPressed: if (currentIndex > 0) chosen(currentIndex - 1)
    Keys.onSpacePressed: open = !open
    Keys.onEscapePressed: e => { if (open) { open = false; e.accepted = true; } else e.accepted = false; }

    Bevel {
        anchors.fill: parent
        kind: "sunken"
        fill: root.enabled ? Theme.window : Theme.face
        Rectangle {
            x: 3; y: 3
            width: parent.width - drop.width - 8
            height: parent.height - 6
            color: root.activeFocus && !root.open ? Theme.select : "transparent"
            Txt {
                x: 3
                width: parent.width - 6
                height: parent.height
                elide: Text.ElideRight
                enabled: root.enabled
                text: root.currentIndex >= 0 && root.currentIndex < root.model.length ? root.textOf(root.model[root.currentIndex]) : root.placeholder
                color: !root.enabled ? Theme.grayText : root.activeFocus && !root.open ? Theme.selectText
                    : root.currentIndex >= 0 ? Theme.windowText : Theme.grayText
            }
        }
    }
    Btn {
        id: drop
        x: parent.width - width - 2
        y: 2
        width: Theme.field - 6
        implicitWidth: Theme.field - 6
        height: parent.height - 4
        glyph: "down"
        padding: 0
        activeFocusOnTab: false
        enabled: root.enabled
        onClicked: { root.forceActiveFocus(); root.open = !root.open; }
    }
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: drop.width + 2
        enabled: root.enabled
        onClicked: { root.forceActiveFocus(); root.open = !root.open; }
    }

    // the list
    Rectangle {
        visible: root.open
        y: root.height
        width: root.width
        height: Math.min(root.maxRows, root.model.length) * (Theme.menuItem - 4) + 2
        color: Theme.window
        border.width: 1
        border.color: Theme.dkShadow
        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 1
            anchors.rightMargin: 1 + (bar.visible ? bar.width : 0)
            clip: true
            model: root.open ? root.model : []
            boundsBehavior: Flickable.StopAtBounds
            property int hot: root.currentIndex
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width
                height: Theme.menuItem - 4
                color: index === list.hot ? Theme.select : "transparent"
                Txt {
                    x: 4
                    width: parent.width - 8
                    height: parent.height
                    elide: Text.ElideRight
                    text: root.textOf(modelData)
                    color: index === list.hot ? Theme.selectText : Theme.windowText
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: list.hot = index
                    onClicked: { root.open = false; root.chosen(index); }
                }
            }
            onVisibleChanged: if (visible) positionViewAtIndex(Math.max(0, root.currentIndex), ListView.Center)
        }
        Scroll {
            id: bar
            flick: list
            x: parent.width - width - 1
            y: 1
            height: parent.height - 2
        }
    }
}
