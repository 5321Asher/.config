import QtQuick
import Quickshell
import Quickshell.Wayland

// Animated card: drops down under `anchorItem`, or slides in from the right edge (side: "right").
// Full-screen transparent layer: clicking anywhere off the card or pressing Esc closes it.
PanelWindow {
    id: root

    property bool open: false
    property Item anchorItem
    property string side: "center"
    readonly property bool fromRight: side === "right"
    default property alias content: body.data

    // Anchor center in screen coordinates, captured on open
    property real anchorX: 0

    signal opened

    visible: open || card.opacity > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popout"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Let clicks through while the close animation plays
    mask: open ? null : noInput

    Region { id: noInput }

    onOpenChanged: if (open) {
        if (anchorItem)
            anchorX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
        scope.forceActiveFocus();
        opened();
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.open = false

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }


        Rectangle {
            id: card

            property real slide: root.open ? 0 : root.fromRight ? 40 : -10

            x: root.fromRight ? root.width - width - 10 + slide
               : Math.round(Math.max(8, Math.min(root.width - width - 8, root.anchorX - width / 2)))
            y: Theme.barHeight + 8 + (root.fromRight ? 0 : slide)
            width: body.width + 48
            height: body.height + 44
            radius: 0
            color: Theme.bg
            border.width: 2
            border.color: Theme.accent

            opacity: root.open ? 1 : 0
            scale: root.open || root.fromRight ? 1 : 0.94
            transformOrigin: Item.Top

            Behavior on slide { NumberAnimation { duration: root.fromRight ? 260 : 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            // Swallow clicks on the card so they don't close it
            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: body
                anchors.centerIn: parent
                width: childrenRect.width
                height: childrenRect.height
            }
        }
    }
}
