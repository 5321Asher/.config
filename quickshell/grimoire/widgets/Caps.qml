import QtQuick
import "../theme"

// Engraved small caps (Cinzel, tracked): labels. Ink by default (for pages); set color on leather.
Text {
    property bool strong: false
    color: Theme.inkDim
    font.family: Theme.caps
    font.pixelSize: Theme.small
    font.letterSpacing: Theme.capsTracking
    font.weight: strong ? Font.Bold : Font.Medium
    font.capitalization: Font.AllUppercase
    renderType: Text.NativeRendering
}
