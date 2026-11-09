import QtQuick
import "../theme"

// (The shared pages' old box.) In Glyph, a rounded tile: `cut` sets the roundness, `corners` is ignored.
Rectangle {
    property real cut: 12
    property string corners: ""
    property color fill: Theme.s1
    property color stroke: Theme.s2
    radius: Math.min(cut * 2.4, Math.min(width, height) / 2)
    color: fill
    border { width: 1; color: stroke }
}
