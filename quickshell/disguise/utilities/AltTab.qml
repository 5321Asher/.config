import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../flyouts"

// The Alt + Tab switcher (AltTabState): a dark Acrylic band across the middle of the screen with a
// live thumbnail of each window, its icon and title above it, the selected one ringed. Letting go of
// Alt (the layer holds the keyboard while it's up) switches; clicking a thumbnail switches to it.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool mine: AltTabState.shown && AltTabState.screenName === modelData.name

    visible: mine
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "disguise-alttab"
    WlrLayershell.keyboardFocus: mine ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int n: AltTabState.wins.length
    // thumbnails shrink to fit the screen, up to Windows' size
    readonly property real thumbH: Math.min(200, (width - 120) / Math.max(1, n) / 1.6 - 16)
    readonly property real thumbW: thumbH * 1.6

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onReleased: e => { if (e.key === Qt.Key_Alt || e.key === Qt.Key_Meta) AltTabState.commit(); }
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) AltTabState.cancel();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) AltTabState.commit();
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) AltTabState.step(1);
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) AltTabState.step(-1);
            else return;
            e.accepted = true;
        }

        MouseArea { anchors.fill: parent; onClicked: AltTabState.cancel() }

        Acrylic {
            id: band
            anchors.centerIn: parent
            width: row.width + 32
            height: root.thumbH + 72
            tint: Theme.dark ? Theme.flyout : "#2b2b2b"

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 16
                Repeater {
                    model: root.mine ? AltTabState.wins : []
                    Item {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool sel: index === AltTabState.sel
                        width: root.thumbW
                        height: root.thumbH + 36

                        Rectangle {        // the selection ring
                            anchors.fill: parent
                            anchors.margins: -6
                            radius: Theme.radiusLarge + 2
                            color: "transparent"
                            border.width: 3
                            border.color: "#ffffff"
                            visible: item.sel
                        }
                        AppIcon { x: 2; y: 4; size: 16; name: Apps.iconFor(item.modelData) }
                        Text {
                            x: 24; y: 3
                            width: parent.width - 26
                            elide: Text.ElideRight
                            text: item.modelData.title || Apps.nameOf(Apps.entryFor(item.modelData))
                            color: "#ffffff"
                            font.family: Theme.font
                            font.pixelSize: Theme.caption
                        }
                        Rectangle {
                            y: 28
                            width: parent.width
                            height: root.thumbH
                            radius: Theme.radius
                            color: "#1f1f1f"
                            clip: true
                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: root.mine && !Apps.isMin(item.modelData) ? item.modelData.wayland : null
                                live: true
                                constraintSize: Qt.size(width, height)
                            }
                            AppIcon {       // minimised: just its icon, as Windows shows
                                visible: Apps.isMin(item.modelData)
                                anchors.centerIn: parent
                                size: 48
                                name: Apps.iconFor(item.modelData)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { AltTabState.sel = item.index; AltTabState.commit(); }
                        }
                    }
                }
            }
        }
    }
    onVisibleChanged: if (visible) keys.forceActiveFocus()
}
