import QtQuick
import "../theme"

// Numbers and short words in Doto with round dots (ROND 100, weight 900). Never under 26 px.
// The frame is tightened like line-height .85 (Doto's line is 1.2 em): negative paddings.
Text {
    readonly property real lead: -0.175 * font.pixelSize
    font { family: Theme.dot; pixelSize: 44; weight: Font.Black; variableAxes: ({ "ROND": 100, "wght": 900 }) }
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
