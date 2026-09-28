import QtQuick
import "../theme"

// A Japanese accent beside a label (システム診断, 接続中): small, in the second colour.
Text {
    color: Theme.cyan
    font.family: Theme.jp
    font.pixelSize: Theme.label + 2
    font.weight: Font.Medium
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
