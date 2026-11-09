import QtQuick
import "../theme"

// A label: Space Mono in caps, tracked .14 em, grey. Size with px (the tracking follows it).
Text {
    property real px: 12
    font { family: Theme.mono; pixelSize: px; letterSpacing: px * 0.14; capitalization: Font.AllUppercase }
    color: Theme.grey
    textFormat: Text.PlainText
}
