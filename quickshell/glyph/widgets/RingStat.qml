import QtQuick
import "../theme"

// A gauge: a ring of dots lit by f, the value in Doto in the middle, a label under it.
Item {
    id: g
    property real f
    property string value
    property string label
    width: 190
    height: 220
    Ring { width: 190; height: 190; n: 44; dot: 6; f: g.f; on: g.f > 0.9 ? Theme.red : Theme.fg }
    Num { x: (190 - width) / 2; y: (190 - height) / 2; text: g.value; font.pixelSize: 64 }
    Lb { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom } text: g.label; px: 10 }
}
