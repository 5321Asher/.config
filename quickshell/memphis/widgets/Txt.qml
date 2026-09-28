import QtQuick
import "../theme"

// Text in the system font. Disabled text is etched (grey, with a white copy a pixel below), like 98.
Text {
    property bool bold: false
    color: enabled ? Theme.text : Theme.grayText
    style: enabled || Theme.dark ? Text.Normal : Text.Raised
    styleColor: Theme.hilight
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: bold
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
