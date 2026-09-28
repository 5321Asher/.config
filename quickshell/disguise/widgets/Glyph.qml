import QtQuick
import "../theme"

// A Segoe Fluent Icons glyph: g is the character ("" = Settings). 16 px unless told.
Text {
    property string g: ""
    property int size: 16
    text: g
    color: Theme.text
    font.family: Theme.icons
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
