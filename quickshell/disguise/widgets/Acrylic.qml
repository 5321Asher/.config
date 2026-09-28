import QtQuick
import QtQuick.Effects
import "../theme"

// A flyout's surface: the Acrylic tint (Hyprland blurs the desktop behind it: look.lua's layer
// rule), 8 px corners, a hairline edge and Windows' soft shadow. tint = Theme.flyout by default.
Item {
    id: root
    default property alias content: body.data
    property color tint: Theme.flyout
    property real tintAlpha: Theme.acrylic
    property int radius: Theme.radiusLarge
    property bool shadow: true

    RectangularShadow {
        visible: root.shadow
        anchors.fill: bg
        offset.y: 8
        radius: root.radius
        blur: 32
        spread: 0
        color: Theme.shadow
    }
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(root.tint, root.tintAlpha)
        border.width: 1
        border.color: Theme.flyoutStroke
    }
    Item { id: body; anchors.fill: parent }
}
