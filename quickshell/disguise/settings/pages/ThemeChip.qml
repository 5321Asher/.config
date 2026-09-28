import QtQuick
import "../../theme"
import "../../widgets"
import ".."

// A colour theme to pick: its accent on a little window, the name under it; ringed when current.
Item {
    id: root
    required property var theme
    width: 132; height: 108
    Rectangle {
        width: parent.width; height: 80; radius: Theme.radiusLarge
        color: Theme.subtle
        border.width: root.theme.current ? 3 : m.containsMouse ? 1 : 0
        border.color: root.theme.current ? Theme.accent : Theme.strong
        Rectangle {
            anchors.centerIn: parent
            width: 70; height: 44; radius: Theme.radius
            color: Theme.dark ? "#2b2b2b" : "#ffffff"
            Rectangle { x: 8; y: 26; width: 36; height: 10; radius: 3; color: root.theme.accent }
            Rectangle { x: 8; y: 8; width: 54; height: 5; radius: 2; color: Theme.text3 }
        }
    }
    Txt { y: 84; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.theme.name; size: Theme.caption }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: if (!root.theme.current) Look.setTheme(root.theme.id) }
}
