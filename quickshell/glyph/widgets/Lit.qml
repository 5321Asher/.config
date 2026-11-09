import QtQuick
import QtQuick.Effects
import "../theme"

// A strip at the screen's edge: the lit segments glow; the unlit ones lie separately, without the
// effect (or the glow would outline the grey ones too).
Item {
    id: root

    property int n
    property real f
    property bool vertical
    property color on: Theme.fg

    Seg { anchors.fill: parent; n: root.n; vertical: root.vertical; f: 0 }
    Seg {
        anchors.fill: parent
        n: root.n
        vertical: root.vertical
        f: root.f
        on: root.on
        off: "transparent"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.glow
            shadowBlur: 0.7
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
