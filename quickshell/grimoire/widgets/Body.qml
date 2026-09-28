import QtQuick
import "../theme"

// Book text (Cardo). Ink by default (for pages).
Text {
    property bool italic: false
    property bool strong: false
    color: Theme.ink
    font.family: Theme.body
    font.pixelSize: Theme.text
    font.italic: italic
    font.weight: strong ? Font.Bold : Font.Normal
    textFormat: Text.PlainText
}
