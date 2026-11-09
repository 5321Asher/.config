import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "pages"

// Settings (`deck open <page>`, the gear in quick settings, Settings in the index), after the
// reference's: a black screen, the sections as a column of Doto words on the left (the open one big
// with the red dot), its page on the right under a label line. ↑↓ (or the wheel over the words)
// change section, Esc closes. Pages are the shared ones (pages/*.qml). State: PrefsState.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    readonly property real s: Theme.scaleFor(screen)

    property real t: PrefsState.open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: PrefsState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-prefs"

    Connections {
        target: PrefsState
        function onOpenChanged() { if (PrefsState.open) keys.forceActiveFocus(); }
        function onPageChanged() { flick.contentY = 0; page.opacity = 0; fadeIn.restart(); }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.bg, 0.97)
        opacity: root.t
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) PrefsState.open = false;
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) PrefsState.step(-1);
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) PrefsState.step(1);
            else return;
            e.accepted = true;
        }
        MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }
    }

    Stage {
        id: stage
        s: root.s
        opacity: root.t
        readonly property bool wide: width >= 1500
        readonly property real lx: wide ? 156 : 60

        // the sections
        Column {
            id: words
            x: stage.lx
            y: stage.wide ? Math.max(80, (stage.height - height) / 2 - 40) : 70
            spacing: stage.wide ? 14 : 6
            transform: Translate { x: -30 * (1 - root.t) }
            Repeater {
                model: PrefsState.pages
                Row {
                    id: w
                    required property var modelData
                    required property int index
                    readonly property bool on: PrefsState.index === index
                    spacing: 26
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: on ? 28 : 0
                        height: 28
                        radius: 14
                        color: Theme.red
                        scale: w.on ? 1 : 0
                        Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on scale { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                    }
                    Num {
                        text: w.modelData.word
                        font.pixelSize: w.on ? (stage.wide ? 96 : 60) : (stage.wide ? 46 : 32)
                        color: w.on ? Theme.fg : mouse.containsMouse ? Theme.grey : Theme.mute
                        Behavior on font.pixelSize { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PrefsState.page = w.modelData.id
                            onWheel: e => PrefsState.step(e.angleDelta.y > 0 ? -1 : 1)
                        }
                    }
                }
            }
        }

        // the page
        Item {
            id: pane
            readonly property real px: stage.wide ? Math.max(words.x + 560, stage.width * 0.42) : stage.lx
            x: px
            y: stage.wide ? 110 : words.y + words.height + 50
            width: Math.min(stage.wide ? 900 : stage.width - 2 * stage.lx, stage.width - px - 100)
            height: stage.height - y - 140

            Row {
                id: head
                spacing: 14
                Lb { text: PrefsState.current.word.toLowerCase(); color: Theme.fg; px: 13 }
                Lb { text: "·"; px: 13 }
                Lb { text: PrefsState.current.sub; px: 13 }
            }

            Flickable {
                id: flick
                anchors { fill: parent; topMargin: 50 }
                contentHeight: page.height + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: page
                    width: flick.width
                    active: root.visible
                    sourceComponent: ({
                        comms: comms, radio: radio, log: log, almanac: almanac, telemetry: telemetry,
                        hangar: hangar, optics: optics, lamps: lamps, chronometer: chronometer, claude: claude
                    })[PrefsState.page] ?? comms
                    NumberAnimation on opacity { id: fadeIn; from: 0; to: 1; duration: Theme.t; running: false }
                }
            }
        }

        Row {
            x: stage.lx
            anchors { bottom: parent.bottom; bottomMargin: 60 }
            spacing: 34
            Lb { text: "↑↓ section" }
            Lb { text: "wheel scroll" }
            Lb { text: "esc close" }
        }
        Rectangle {
            anchors { right: parent.right; rightMargin: 60; bottom: parent.bottom; bottomMargin: 48 }
            width: 54
            height: 54
            radius: 27
            color: closeH.hovered ? Theme.s3 : Theme.s2
            Icon { anchors.centerIn: parent; text: "\u{F0156}"; font.pixelSize: 22 }
            HoverHandler { id: closeH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: PrefsState.open = false }
        }
    }

    // referenced as types (not by path) so live reload sees edits
    Component { id: comms; Comms {} }
    Component { id: radio; Airwaves {} }
    Component { id: log; Log {} }
    Component { id: almanac; Almanac {} }
    Component { id: telemetry; Telemetry {} }
    Component { id: hangar; Hangar {} }
    Component { id: optics; Optics {} }
    Component { id: lamps; Lamps {} }
    Component { id: chronometer; Chrono {} }
    Component { id: claude; Claude {} }
}
