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

    // Always mapped, taking no input while nothing is open: mapping a layer made Hyprland re-send the
    // pointer to the taskbar under it, and the next click there (the one that should close the
    // flyout again) was lost
    visible: true
    mask: mine ? null : noInput
    Region { id: noInput; item: nothing }
    Item { id: nothing; width: 0; height: 0 }
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

        Slide {
            // the emoji panel / clipboard history (Win + . / Win + V), at the pointer like Windows puts
            // it at the caret; kept on screen and above the taskbar
            k: "emoji"
            width: 360
            height: Math.min(460, root.sh - 24)
            x: Math.max(12, Math.min(root.sw - width - 12, (Flyouts.opts.x ?? root.sw - 380) - (root.modelData.x ?? 0) - 24))
            y: Math.max(12, Math.min(root.sh - height - Theme.flyoutGap, (Flyouts.opts.y ?? root.sh) - (root.modelData.y ?? 0) + 18))
            EmojiPanel { anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
        }

        Slide {
            // Run (Win + R): bottom left, where Windows puts it
            k: "run"
            width: Math.min(420, root.sw - 24)
            height: 232
            x: Theme.flyoutGap
            y: root.sh - height - Theme.flyoutGap
            RunDialog { anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
        }

        Slide {
            // the scripts' questions (web apps, keybinds): a content dialog in the middle of the screen
            k: "prompt"
            width: Math.min(480, root.sw - 24)
            height: promptDialog.implicitHeight
            x: Math.round((root.sw - width) / 2)
            y: Math.round((root.sh - height) / 2.4)
            PromptDialog { id: promptDialog; anchors.fill: parent; screenName: root.modelData.name; active: parent.active }
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

    onMineChanged: if (mine) keys.forceActiveFocus()
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
