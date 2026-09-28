import QtQuick
import QtQuick.Controls.Basic as C
import "../theme"

// A WinUI combo box: a button with the choice and a chevron; the list drops over it with the
// chosen row (and its accent pill) where the button was.
Item {
    id: root

    property var model: []
    property var textOf: x => String(x)
    property int currentIndex: -1
    signal chosen(int index)

    implicitWidth: 240
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1 : 0.45

    Btn {
        id: button
        anchors.fill: parent
        onClicked: pop.open()
    }
    Txt {
        x: 11
        width: parent.width - 44
        height: parent.height
        text: root.currentIndex >= 0 && root.currentIndex < root.model.length ? root.textOf(root.model[root.currentIndex]) : ""
    }
    Glyph {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        g: ""
        size: 12
        color: Theme.text2
    }

    C.Popup {
        id: pop
        readonly property int rows: Math.min(root.model.length, 8)
        width: root.width
        height: rows * 36 + 8
        y: -Math.max(0, Math.min(root.currentIndex, rows - 1)) * 36 - 4
        padding: 4
        modal: false
        focus: true
        background: Acrylic { tintAlpha: 1 }
        contentItem: ListView {
            clip: true
            model: root.model
            currentIndex: root.currentIndex
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 36
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.radius
                    color: rowMouse.containsMouse || index === root.currentIndex ? Theme.subtle : "transparent"
                    Rectangle {
                        visible: index === root.currentIndex
                        width: 3; height: 16; radius: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                    }
                    Txt { x: 12; width: parent.width - 16; height: parent.height; text: root.textOf(modelData) }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { pop.close(); root.chosen(index); }
                }
            }
        }
    }
}
