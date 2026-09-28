import QtQuick
import "../theme"

// Text in Segoe UI Variable, Windows' body size and colour unless told otherwise.
// strong = semibold; level 2 / 3 = secondary / tertiary text.
Text {
    property bool strong: false
    property int size: Theme.body
    property int level: 1
    color: level === 3 ? Theme.text3 : level === 2 ? Theme.text2 : Theme.text
    font.family: size >= 28 ? Theme.fontDisplay : size <= 11 ? Theme.fontSmall : Theme.font
    font.pixelSize: size
    font.weight: strong ? Font.DemiBold : Font.Normal
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    renderType: Text.NativeRendering
}
