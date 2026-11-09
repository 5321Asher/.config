import QtQuick
import "../theme"

// A canvas in design pixels (a 1080-high screen at s = 1), stretched over its parent: everything
// inside is measured as in the reference, and `s` (Theme.scaleFor(screen)) makes it fit.
Item {
    property real s: 1
    width: parent.width / s
    height: parent.height / s
    scale: s
    transformOrigin: Item.TopLeft
}
