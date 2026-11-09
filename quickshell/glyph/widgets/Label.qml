import QtQuick
import "../theme"

// The tracked-caps label the shared pages use (Lb with a `strong` switch: fg instead of grey).
Lb {
    property bool strong: false
    px: 11
    color: strong ? Theme.fg : Theme.grey
    verticalAlignment: Text.AlignVCenter
}
