import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"

// The subnet map's corner: a few pixels in the top-left of a screen, over the bar. Resting the
// pointer there only lights it (a red wedge grows out of the corner); a click opens the map from
// that corner. (niri's push-to-open hot corner is off while Netrunner is the setup: hypr/feels/niri.lua.)
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { top: true; left: true }
    implicitWidth: 6
    implicitHeight: 6
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-corner"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { OverviewState.origin = Qt.point(0, 0); OverviewState.toggle(); }
    }
    Rectangle { anchors.fill: parent; color: hit.containsMouse ? Theme.red : "transparent" }
}
