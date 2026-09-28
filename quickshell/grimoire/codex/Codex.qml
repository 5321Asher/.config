import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../utilities"
import "pages"

// The codex: Grimoire's control panel, an open book laid on the desk in the middle of the focused
// screen. The left page is its table of contents (the chapters with red numerals and dotted leaders,
// and a few facts at the foot); the right page is the chapter you're reading, headed by an
// illuminated capital. Turning to another chapter turns a leaf across the spread. A silk bookmark
// hangs from the gutter. Esc or a click on the desk closes it; Tab / Page Down turn forward.
//   qs ipc call deck open <page>   (helm comms radio log almanac telemetry hangar optics lamps chronometer claude)
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: CodexState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-codex"
    WlrLayershell.keyboardFocus: CodexState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: CodexState.open ? null : noInput
    Region { id: noInput }

    property real shown: CodexState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
    onVisibleChanged: if (visible) keys.forceActiveFocus()

    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "codex") keys.grabToImage(r => r.saveToFile(path)); }
    }

    // two pages side by side when there's room, else just the chapter
    readonly property real pageW: Math.min(Theme.codexPageWidth, (width - 120) / 2)
    readonly property bool spread: pageW >= 400
    readonly property real rightW: spread ? pageW : Math.min(Theme.codexPageWidth, width - 40)
    readonly property real pageH: Math.min(Theme.codexHeight, height - 90)

    // ---------------------------------------------------------------- turning
    // the leaf sweeps from the right page to the left (forward) or back; the chapter changes under it
    property real leaf: 0              // 0 = flat on its start page, 1 = flat on the other
    property int leafDir: 1
    property string showing: CodexState.page
    Connections {
        target: CodexState
        function onPageChanged() {
            if (!root.visible) { root.showing = CodexState.page; return; }
            root.leafDir = CodexState.turning;
            turn.restart();
        }
    }
    SequentialAnimation {
        id: turn
        NumberAnimation { target: root; property: "leaf"; from: 0; to: 0.5; duration: 240; easing.type: Easing.InQuad }
        ScriptAction { script: root.showing = CodexState.page }
        NumberAnimation { target: root; property: "leaf"; from: 0.5; to: 1; duration: 300; easing.type: Easing.OutQuad }
        PropertyAction { target: root; property: "leaf"; value: 0 }
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: CodexState.open = false
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Tab || e.key === Qt.Key_PageDown) { CodexState.step(1); e.accepted = true; }
            else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_PageUp) { CodexState.step(-1); e.accepted = true; }
        }

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.veil, 0.5 * root.shown) }
        MouseArea { anchors.fill: parent; onClicked: CodexState.open = false }

        // ---------------------------------------------------------------- the book
        Item {
            id: book
            width: (root.spread ? root.pageW * 2 : root.rightW) + 28
            height: root.pageH + 26
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 12 + (1 - root.shown) * 40
            opacity: root.shown
            scale: 0.96 + 0.04 * root.shown

            MouseArea { anchors.fill: parent }

            // shadow, then the cover under the pages
            Rectangle {
                x: 10; y: 16; width: parent.width; height: parent.height; radius: 8
                color: Qt.alpha("#000000", 0.55)
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 }
            }
            Leather { anchors.fill: parent; radius: 8; toolInset: 5 }

            // page edges peeking out below the pages
            Rectangle { x: 12; y: parent.height - 13; width: parent.width - 24; height: 3; radius: 1; color: Theme.mix(Theme.pageDeep, Theme.ink, 0.15) }
            Rectangle { x: 13; y: parent.height - 11; width: parent.width - 26; height: 1; color: Theme.alpha(Theme.ink, 0.25) }

            // ---------------------------------------------------------------- left page: the contents
            Parchment {
                id: leftPage
                visible: root.spread
                x: 14; y: 10
                width: root.pageW
                height: root.pageH
                radius: 3
                Contents { anchors.fill: parent }
                // the gutter's shade
                Rectangle {
                    anchors.right: parent.right
                    width: 46; height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Theme.alpha(Theme.ink, 0.22) }
                    }
                }
            }

            // ---------------------------------------------------------------- right page: the chapter
            Parchment {
                id: rightPage
                x: root.spread ? 14 + root.pageW : 14
                y: 10
                width: root.rightW
                height: root.pageH
                radius: 3

                Rectangle {
                    visible: root.spread
                    width: 46; height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.alpha(Theme.ink, 0.22) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                Item {
                    id: chapter
                    anchors.fill: parent
                    anchors.leftMargin: root.spread ? 46 : 30
                    anchors.rightMargin: 34
                    anchors.topMargin: 30
                    anchors.bottomMargin: 42
                    readonly property var info: CodexState.pages.find(p => p.id === root.showing) ?? CodexState.pages[0]

                    // single page: the chapters as a row of numerals across the top
                    Flow {
                        id: miniToc
                        visible: !root.spread
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: CodexState.pages
                            Btn { required property var modelData; required property int index; text: Theme.roman(index + 1)
                                  on: CodexState.page === modelData.id; onClicked: CodexState.turnTo(modelData.id) }
                        }
                    }

                    Row {
                        id: head
                        y: root.spread ? 0 : miniToc.height + 14
                        spacing: 14
                        Initial { letter: chapter.info.title.charAt(0); size: 56 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: chapter.info.title.slice(1).length ? chapter.info.title : ""; color: Theme.ink; font.family: Theme.uncial; font.pixelSize: 30 }
                            Body { text: chapter.info.sub; italic: true; color: Theme.inkDim; font.pixelSize: 14 }
                        }
                    }
                    GoldRule { id: headRule; y: head.y + head.height + 8; width: parent.width; color: Theme.alpha(Theme.inkDim, 0.6); ornament: "❦" }

                    Flickable {
                        id: flick
                        y: headRule.y + headRule.height + 12
                        width: parent.width
                        height: parent.height - y
                        clip: true
                        contentHeight: loader.item ? loader.item.implicitHeight + 20 : 0
                        boundsBehavior: Flickable.StopAtBounds
                        Loader {
                            id: loader
                            width: flick.width
                            active: root.visible
                            sourceComponent: root.components[root.showing] ?? null
                            onLoaded: flick.contentY = 0
                        }
                    }
                    // where you are in a long chapter: a thin red rule in the margin
                    Rectangle {
                        visible: flick.contentHeight > flick.height
                        x: parent.width + 14
                        y: flick.y + flick.visibleArea.yPosition * flick.height
                        width: 2
                        height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
                        radius: 1
                        color: Theme.alpha(Theme.rubric, 0.7)
                    }
                }
                // the folio
                Body {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    text: "— " + Theme.roman(CodexState.pages.findIndex(p => p.id === root.showing) * 2 + 3).toLowerCase() + " —"
                    italic: true
                    color: Theme.inkDim
                    font.pixelSize: 13
                }
            }

            // ---------------------------------------------------------------- the turning leaf
            Item {
                id: leafItem
                visible: turn.running && root.spread
                x: 14 + root.pageW
                y: 10
                width: root.pageW
                height: root.pageH
                // forward: starts on the right page and swings over to the left; back: the reverse
                readonly property real angle: root.leafDir > 0 ? -180 * root.leaf : -180 * (1 - root.leaf)
                transform: Rotation {
                    origin.x: 0
                    origin.y: leafItem.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: leafItem.angle
                }
                Parchment { anchors.fill: parent; radius: 3; age: 0.35 }
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    // darker as it stands up edge-on
                    color: Theme.alpha(Theme.ink, 0.35 * Math.sin(Math.abs(leafItem.angle) * Math.PI / 180))
                }
            }

            // the bookmark, lying in the gutter and hanging out past the foot of the book
            Item {
                visible: root.spread
                x: 14 + root.pageW - width / 2
                y: 6
                width: 14
                height: root.pageH + 58
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 7
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.darker(Theme.arcane, 1.8) }
                        GradientStop { position: 0.45; color: Qt.lighter(Theme.arcane, 1.08) }
                        GradientStop { position: 1; color: Qt.darker(Theme.arcane, 1.9) }
                    }
                }
                // the swallowtail
                Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: -4
                       text: "▼"; color: Theme.leather; font.pixelSize: 13 }
            }
        }
    }

    // chapters as types (so live reload sees them)
    readonly property var components: ({
        helm: helm, comms: comms, radio: radio, log: log, almanac: almanac, telemetry: telemetry,
        hangar: hangar, optics: optics, lamps: lamps, chronometer: chrono, claude: claude,
    })
    Component { id: helm; Sanctum {} }
    Component { id: comms; Sendings {} }
    Component { id: radio; Minstrelsy {} }
    Component { id: log; LettersPage {} }
    Component { id: almanac; Almanac {} }
    Component { id: telemetry; Alchemy {} }
    Component { id: hangar; Reliquary {} }
    Component { id: optics; Scrying {} }
    Component { id: lamps; Lanterns {} }
    Component { id: chrono; Hourglass {} }
    Component { id: claude; Familiar {} }
}
