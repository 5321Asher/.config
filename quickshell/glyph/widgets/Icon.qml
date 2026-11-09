import QtQuick
import "../theme"

// A Nerd Font (Material Design) glyph in a 1 em frame.
Text {
    readonly property real lead: -0.16 * font.pixelSize
    font { family: Theme.nf; pixelSize: 19 }
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
