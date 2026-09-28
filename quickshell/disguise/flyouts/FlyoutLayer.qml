import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"

// Draws the open flyout (Flyouts.kind) on one screen: a clear layer over the desktop above the
// taskbar (it keeps out of the taskbar's zone, so the taskbar still works while a flyout is open).
// A click anywhere else closes it, as on Windows; so does Esc. Flyouts rise from the taskbar
// (Widgets slides in from the left) and fall back when closing.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool mine: Flyouts.isOpen && Flyouts.screen === modelData.name
    readonly property string kind: mine ? Flyouts.kind : ""

    visible: mine
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "disguise-flyout"
    // Not an exclusive keyboard grab: while a layer holds one, Hyprland gives clicks to nothing
    // else, so the taskbar button that opened a flyout couldn't close it. A Hyprland focus grab
    // keeps the keyboard here and lets the taskbar work; a click anywhere else clears it.
    WlrLayershell.keyboardFocus: mine ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    HyprlandFocusGrab {
        active: root.mine && !Flyouts.closing
        windows: [root].concat(Flyouts.bars[root.modelData.name] ? [Flyouts.bars[root.modelData.name]] : [])
        onCleared: Flyouts.close()
    }

    // the screen's size (the layer's is 0 until it's first mapped)
    readonly property real sw: width > 0 ? width : modelData.width
    readonly property real sh: height > 0 ? height : modelData.height - Theme.taskbarHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: Flyouts.levels.length && Flyouts.kind !== "menu" ? Flyouts.closeMenu() : Flyouts.close()
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (Flyouts.levels.length) {
                const deepest = menus.itemAt(Flyouts.levels.length - 1);
                if (e.key === Qt.Key_Escape) { Flyouts.levels.length > 1 ? Flyouts.levels = Flyouts.levels.slice(0, -1) : Flyouts.closeMenu(); e.accepted = true; return; }
                if (deepest && deepest.key(e)) { e.accepted = true; return; }
            }
            if (e.key === Qt.Key_Escape) { Flyouts.close(); e.accepted = true; }
        }

        // ------------------------------------------------------------ the flyouts
        Slide {
            k: "start"
            width: Math.min(Theme.startWidth, root.sw - 24)
            height: Math.min(Theme.startHeight, root.sh - Theme.flyoutGap - 12)
            x: Math.round((root.sw - width) / 2)
            y: root.sh - height - Theme.flyoutGap
            StartMenu { anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
        }
        Slide {
            k: "search"
            width: Math.min(Theme.startWidth + 140, root.sw - 24)
            height: Math.min(640, root.sh - Theme.flyoutGap - 12)
            x: Math.round((root.sw - width) / 2)
            y: root.sh - height - Theme.flyoutGap
            SearchPane { anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
        }
        Slide {
            k: "quick"
            width: Theme.quickWidth
            height: quick.implicitHeight
            x: root.sw - width - Theme.flyoutGap
            y: root.sh - height - Theme.flyoutGap
            QuickSettings { id: quick; anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
        }
        Slide {
            k: "notif"
            width: Theme.quickWidth + 24
            height: root.sh - Theme.flyoutGap - 12
            x: root.sw - width - Theme.flyoutGap
            y: root.sh - height - Theme.flyoutGap
            NotificationCenter { anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
        }
        Slide {
            k: "widgets"
            fromLeft: true
            width: Math.min(Theme.widgetsWidth, root.sw - 24)
            height: root.sh - Theme.flyoutGap - 12
            x: Theme.flyoutGap
            y: 12
            WidgetsBoard { anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
        }
        Slide {
            k: "tray"
            width: tray.implicitWidth
            height: tray.implicitHeight
            x: Math.max(8, Math.min(root.sw - width - 8, (Flyouts.opts.x ?? root.sw - 200) - width / 2))
            y: root.sh - height - Theme.flyoutGap
            TrayOverflow { id: tray; anchors.fill: parent; screenName: root.modelData.name }
        }

        // ------------------------------------------------------------ context menus, on top
        Repeater {
            id: menus
            model: ScriptModel { values: root.mine ? [...Array(Flyouts.levels.length).keys()] : [] }
            MenuPanel {
                required property int modelData
                depth: modelData
                level: Flyouts.levels[modelData] ?? ({ items: [], x: 0, y: 0 })
                areaWidth: root.sw
                areaHeight: root.sh
                z: 100 + modelData
            }
        }
    }

    onVisibleChanged: if (visible) keys.forceActiveFocus()
    Connections {
        target: Flyouts
        function onKindChanged() { if (root.mine) keys.forceActiveFocus(); }
    }

    // A flyout's frame: shown while its kind is open; rises (or slides in from the left) as it
    // opens and sinks away as it closes.
    component Slide: Item {
        id: slide
        property string k
        property bool fromLeft: false
        readonly property bool active: root.kind === k && !Flyouts.closing
        visible: root.kind === k
        opacity: active ? 1 : 0
        transform: Translate {
            y: slide.fromLeft ? 0 : (slide.active ? 0 : 36)
            x: slide.fromLeft ? (slide.active ? 0 : -60) : 0
            Behavior on y { NumberAnimation { duration: slide.active ? Theme.normal : 120; easing.type: slide.active ? Easing.OutCubic : Easing.InCubic } }
            Behavior on x { NumberAnimation { duration: slide.active ? Theme.normal : 120; easing.type: slide.active ? Easing.OutCubic : Easing.InCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: slide.active ? Theme.fast : 110 } }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: if (Flyouts.levels.length) Flyouts.closeMenu() }
    }
}
