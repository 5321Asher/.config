import QtQuick
import "../theme"

// The small tracked uppercase mono label everything in Netrunner wears ("MEM // 5.5 / 15.3 GB").
Text {
    property bool strong: false
    color: strong ? Theme.fg : Theme.dim
    font.family: Theme.mono
    font.pixelSize: Theme.label
    font.letterSpacing: Theme.tracking
    font.capitalization: Font.AllUppercase
    font.weight: strong ? Font.DemiBold : Font.Normal
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
