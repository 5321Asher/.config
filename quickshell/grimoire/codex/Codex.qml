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
// illuminated capital. Turning to another chapter turns a real leaf (shaders/curl.frag).
// Esc or a click on the desk closes it; Tab / Page Down turn forward.
//   qs ipc call deck open <page>   (helm comms radio log almanac telemetry hangar optics lamps chronometer claude)
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden: moving a shown window rebuilds its surface
    // (it vanished for a few frames mid-fade on close, when the keyboard grab let go).
    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
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
    // A real leaf (shaders/curl.frag): forward, a picture of the old chapter curls up from its corner
    // and over onto the left page, uncovering the new one; back, the new chapter's page comes over
    // from the left and lays itself down on the old. The chapter changes a frame after the picture.
    property real leaf: 0              // 0 = flat on the right page, 1 = turned over onto the left
    property int leafDir: 1
    property bool turning: false
    property string showing: CodexState.page
    Connections {
        target: CodexState
        function onPageChanged() {
            if (!root.visible || !root.spread) { root.showing = CodexState.page; return; }
            turn.stop();
            root.leafDir = CodexState.turning;
            oldShot.scheduleUpdate();
            root.turning = true;
            root.leaf = root.leafDir > 0 ? 0 : 1;
            swap.restart();
        }
    }
    Timer {
        id: swap
        interval: 40
        onTriggered: { root.showing = CodexState.page; turn.to = root.leafDir > 0 ? 1 : 0; turn.restart(); }
    }
    NumberAnimation {
        id: turn
        target: root
        property: "leaf"
        duration: 680
        easing.type: Easing.InOutSine
        onFinished: root.turning = false
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
                gutter: 1
                seed: 0.21
                Contents { anchors.fill: parent }
            }

            // ---------------------------------------------------------------- right page: the chapter
            Parchment {
                id: rightPage
                x: root.spread ? 14 + root.pageW : 14
                y: 10
                width: root.rightW
                height: root.pageH
                radius: 3
                gutter: root.spread ? -1 : 0
                seed: 0.83

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
                            Text { text: chapter.info.title.slice(1).length ? chapter.info.title : ""; color: Theme.ink; font.family: Theme.display; font.weight: Font.DemiBold; font.pixelSize: 30 }
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
            // pictures of the right page: the old chapter (taken just before it changes) and the live one
            ShaderEffectSource {
                id: oldShot
                x: rightPage.x; y: rightPage.y
                width: rightPage.width; height: rightPage.height
                sourceItem: rightPage
                live: false
                // going back, the old chapter stays on the page while the new one comes over it
                visible: root.turning && root.leafDir < 0
            }
            ShaderEffectSource {
                id: liveShot
                sourceItem: rightPage
                live: true
                hideSource: root.turning && root.leafDir < 0
                visible: false
            }
            ShaderEffect {
                visible: root.turning
                x: 14; y: 10
                width: root.pageW * 2
                height: root.pageH
                property var source: root.leafDir > 0 ? oldShot : liveShot
                property size size: Qt.size(width, height)
                property real pageW: root.pageW
                property real fold: root.pageW * (1 - root.leaf)
                property real radius: 2 + root.pageW * 0.2 * Math.sin(Math.PI * root.leaf)
                property real tilt: 0.3 * Math.sin(Math.PI * root.leaf)
                property real settle: Math.max(0, (root.leaf - 0.72) / 0.28)
                property color paper: Theme.page
                fragmentShader: Theme.shaders + "curl.frag.qsb"
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
