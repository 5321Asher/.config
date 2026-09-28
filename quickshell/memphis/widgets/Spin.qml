import QtQuick
import "../theme"

// A number box with 98's little up / down buttons ("spin box"). changed(v) when it's stepped,
// scrolled or typed (Enter).
Bevel {
    id: root

    property int value: 0
    property int from: 0
    property int to: 999
    property string suffix: ""
    signal changed(int v)

    kind: "sunken"
    fill: enabled ? Theme.window : Theme.face
    implicitWidth: 90
    implicitHeight: Theme.field

    function set(v) { changed(Math.max(from, Math.min(to, v))); }

    TextInput {
        id: input
        x: 5
        width: parent.width - 30
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        text: root.value + root.suffix
        color: root.enabled ? Theme.windowText : Theme.grayText
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        renderType: Text.NativeRendering
        selectByMouse: true
        onAccepted: root.set(parseInt(text) || root.from)
        onActiveFocusChanged: if (!activeFocus) text = Qt.binding(() => root.value + root.suffix)
    }
    Column {
        x: parent.width - 20
        y: 2
        Btn { width: 18; implicitWidth: 18; height: (root.height - 4) / 2; implicitHeight: height; padding: 0; activeFocusOnTab: false
              glyph: "up"; enabled: root.enabled; onClicked: root.set(root.value + 1) }
        Btn { width: 18; implicitWidth: 18; height: (root.height - 4) / 2; implicitHeight: height; padding: 0; activeFocusOnTab: false
              glyph: "down"; enabled: root.enabled; onClicked: root.set(root.value - 1) }
    }
    WheelHandler { onWheel: e => root.set(root.value + (e.angleDelta.y > 0 ? 1 : -1)) }
}
