import QtQuick
import "../theme"

// A segmented meter: `count` blocks, the first value * count lit ("CPU ▮▮▯▯▯").
Row {
    id: root

    property real value: 0
    property int count: 5
    property int blockWidth: 4
    property int blockHeight: 12
    property color color: Theme.cyan
    property color off: Theme.alpha(Theme.dim, 0.35)

    spacing: 2
    Repeater {
        model: root.count
        Rectangle {
            required property int index
            width: root.blockWidth
            height: root.blockHeight
            color: index < Math.round(Math.max(0, Math.min(1, root.value)) * root.count) ? root.color : root.off
        }
    }
}
