import QtQuick
import "../theme"

// A tab control ("property sheet" pages): a row of tabs over a raised panel. The selected tab is
// taller and joins the panel. Children are the pages, in the same order as `tabs`; only the
// current one is shown.
Item {
    id: root

    property var tabs: []
    property int current: 0
    default property alias pages: stack.data

    signal picked(int index)

    onCurrentChanged: show()
    Component.onCompleted: show()
    // pages fill the panel; only the current one shows
    function show() {
        for (let i = 0; i < stack.children.length; i++) {
            const c = stack.children[i];
            c.width = Qt.binding(() => stack.width);
            c.height = Qt.binding(() => stack.height);
            c.visible = i === current;
        }
    }
    Connections { target: stack; function onChildrenChanged() { root.show(); } }

    // the panel
    Bevel {
        id: panel
        anchors.fill: parent
        anchors.topMargin: Theme.tabHeight
        kind: "raised"
        fill: Theme.face
    }
    Item {
        id: stack
        anchors.fill: panel
        anchors.margins: Theme.pad
    }

    // the tabs
    Row {
        x: 2
        Repeater {
            model: root.tabs
            Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool sel: index === root.current
                width: label.implicitWidth + 20 + (sel ? 4 : 0)
                height: Theme.tabHeight + (sel ? 2 : 0)
                x: sel ? -2 : 0
                y: sel ? 0 : 2
                z: sel ? 2 : 1

                // left, top and right edges; the rounded corners are a missing pixel
                Rectangle { x: 0; y: 2; width: 1; height: parent.height - 2; color: Theme.hilight }
                Rectangle { x: 1; y: 1; width: 1; height: 1; color: Theme.hilight }
                Rectangle { x: 2; y: 0; width: parent.width - 4; height: 1; color: Theme.hilight }
                Rectangle { x: parent.width - 2; y: 1; width: 1; height: 1; color: Theme.dkShadow }
                Rectangle { x: parent.width - 1; y: 2; width: 1; height: parent.height - 2; color: Theme.dkShadow }
                Rectangle { x: parent.width - 2; y: 2; width: 1; height: parent.height - 2; color: Theme.shadow }
                Rectangle { x: 1; y: 2; width: parent.width - 3; height: parent.height - 1; color: Theme.face }
                Txt {
                    id: label
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: tab.sel ? -1 : 0
                    text: tab.modelData
                    FocusRect { anchors.fill: parent; anchors.margins: -2; visible: tab.sel && root.activeFocus }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.current = tab.index; root.picked(tab.index); }
                }
            }
        }
    }
}
