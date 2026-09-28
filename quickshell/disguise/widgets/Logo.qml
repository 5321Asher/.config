import QtQuick
import "../theme"

// The four panes of Windows 11's Start button, in its blues.
Item {
    id: root
    property real size: 20
    width: size
    height: size
    readonly property real gap: Math.max(1, size * 0.06)
    readonly property real pane: (size - gap) / 2
    Repeater {
        model: 4
        Rectangle {
            required property int index
            x: (index % 2) * (root.pane + root.gap)
            y: Math.floor(index / 2) * (root.pane + root.gap)
            width: root.pane
            height: root.pane
            radius: root.size * 0.025
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.logoTop }
                GradientStop { position: 1; color: Theme.logoBottom }
            }
        }
    }
}
