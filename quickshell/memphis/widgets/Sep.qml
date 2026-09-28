import QtQuick
import "../theme"

// An etched line: grey with white under it (menus, dialogs). vertical: grey with white beside it.
Item {
    property bool vertical: false
    implicitWidth: vertical ? 2 : 100
    implicitHeight: vertical ? 100 : 2
    Rectangle { width: parent.vertical ? 1 : parent.width; height: parent.vertical ? parent.height : 1; color: Theme.shadow }
    Rectangle {
        x: parent.vertical ? 1 : 0; y: parent.vertical ? 0 : 1
        width: parent.vertical ? 1 : parent.width; height: parent.vertical ? parent.height : 1
        color: Theme.hilight
    }
}
