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

    // Opening (op 0 -> 1): the book arrives closed, its cover swings over on the spine, two leaves
    // riffle after it, and it lies open at the chapter. Closing plays it backwards, quicker.
    property real op: 0
    readonly property real shown: Math.min(1, op * 5)
    // driven frame by frame, and never more than a thirtieth of a second per frame, so the first
    // frames (while the window maps and the chapter loads) can't swallow the start of it
    FrameAnimation {
        running: root.op !== (CodexState.open ? 1 : 0)
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30);
            root.op = CodexState.open ? Math.min(1, root.op + dt / 1.35) : Math.max(0, root.op - dt / 0.8);
        }
    }
    function phase(a, b) { const t = Math.max(0, Math.min(1, (op - a) / (b - a))); return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }
    readonly property real arrive: phase(0, 0.14)
    readonly property real coverT: spread ? phase(0.1, 0.52) : 1
    readonly property real leaf1T: spread ? phase(0.42, 0.74) : 1
    readonly property real leaf2T: spread ? phase(0.58, 0.97) : 1
    readonly property bool settled: leaf2T >= 1
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
    // Real leaves (shaders/curl.frag), one for every chapter you pass: from Sanctum to Familiar ten
    // leaves riffle over, from one chapter to the next just one. Forward, a picture of the old chapter
    // curls up first and over onto the left page, then the leaves of the chapters between (each shows
    // its chapter's heading as it goes by), uncovering the new one; back, the leaves come over from the
    // left one after another, the new chapter's page last, on top. A turned leaf's back is the left
    // page, so it lands without a fade. The chapter changes a frame after the picture is taken.
    property int leafDir: 1
    property bool turning: false
    // the chapter drawn on the right page, and the one we're turning from: plain values, not
    // bindings to CodexState (a binding would already say the new chapter by the time the change
    // handler runs, and the new page would show under the leaves before they turn)
    property string showing: ""
    property int fromIdx: 0
    Component.onCompleted: { showing = CodexState.page; fromIdx = CodexState.index; }
    // the leaves of this turn: { kind: "old" | "live" | "title", chapter }
    property var leaves: []
    readonly property int nLeaves: leaves.length
    // how long each leaf takes, and how far behind the one before it it starts (s)
    readonly property real leafDur: nLeaves > 1 ? Math.max(0.38, 0.72 - 0.04 * nLeaves) : 0.75
    readonly property real leafGap: nLeaves > 1 ? Math.min(0.14, 0.8 / (nLeaves - 1)) : 0
    readonly property real turnDur: leafDur + leafGap * Math.max(0, nLeaves - 1)
    property real turnP: 0              // the whole turn, 0 -> 1
    function leafAt(k) {                 // leaf k: 0 flat on the right .. 1 over on the left
        const t = Math.max(0, Math.min(1, (turnP * turnDur - k * leafGap) / leafDur));
        const e = (1 - Math.cos(Math.PI * t)) / 2;
        return leafDir > 0 ? e : 1 - e;
    }
    Connections {
        target: CodexState
        function onPageChanged() {
            const from = root.fromIdx, to = CodexState.index;
            root.fromIdx = to;
            if (!root.visible || !root.spread) { root.showing = CodexState.page; return; }
            const n = Math.max(1, Math.abs(to - from));
            root.leafDir = to > from ? 1 : -1;
            const list = [];
            for (let k = 0; k < n; k++) {
                if (root.leafDir > 0) list.push(k === 0 ? { kind: "old", chapter: from } : { kind: "title", chapter: from + k });
                else list.push(k === n - 1 ? { kind: "live", chapter: to } : { kind: "title", chapter: from - 1 - k });
            }
            oldShot.scheduleUpdate();
            root.leaves = list;
            root.turnP = 0;
            root.turning = true;
            running_.value = false;
            swap.restart();
        }
    }
    QtObject { id: running_; property bool value: false }
    // a few frames for the leaves' pictures to be drawn before the chapter under them changes
    Timer {
        id: swap
        interval: 110
        onTriggered: { root.showing = CodexState.page; running_.value = true; }
    }
    // frame by frame, at most a thirtieth of a second a frame: loading the new chapter stalls a few
    // frames, and a timed animation would jump straight past most of the turn
    FrameAnimation {
        running: root.turning && running_.value
        onTriggered: {
            root.turnP = Math.min(1, root.turnP + Math.min(frameTime, 1 / 30) / root.turnDur);
            if (root.turnP >= 1) { root.turning = false; running_.value = false; root.leaves = []; }
        }
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
            anchors.verticalCenterOffset: 12 + (1 - root.arrive) * 50
            // closed, the book sits centred: it slides left by half as the cover opens
            anchors.horizontalCenterOffset: root.spread ? (root.pageW + 14) / 2 * (1 - root.coverT) : 0
            opacity: root.arrive
            scale: 0.95 + 0.05 * root.arrive

            MouseArea { anchors.fill: parent }

            readonly property real spine: root.spread ? 14 + root.pageW : 0
            readonly property real openW: book.width - book.spine          // one board, spine to edge
            // a room light from above and to the left
            readonly property vector3d lamp: Qt.vector3d(book.width * 0.15, -book.height * 0.35, 1100)

            // shadow: under the closed book, spreading left as it opens
            Rectangle {
                x: book.spine - (book.spine) * root.coverT + 10; y: 18
                width: book.width - x + 10; height: parent.height
                radius: 8
                color: Qt.alpha("#000000", 0.55)
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
            }
            // the back board (right) and, for a single page, the whole cover
            Cover {
                z: 0
                x: book.spine - (root.spread ? 4 : 0)
                width: book.width - x
                height: parent.height
                radius: 8
                bevel: 8
                wear: 0.5
                seed: 0.52
                light: Qt.vector3d(book.lamp.x - x, book.lamp.y, book.lamp.z)
                lightPower: 1.4
                ambient: 0.85
            }
            // the page blocks, seen at the foot
            PageBlock {
                z: 2
                x: book.spine + 2; y: 10 + root.pageH - 1
                width: root.rightW - 4; height: 6
                shadeDepth: 0.6
            }
            PageBlock {
                z: 2
                visible: root.spread && root.settled
                x: 16; y: 10 + root.pageH - 1
                width: root.pageW - 4; height: 6
                shadeDepth: 0.6
                seedValue: 0.8
            }

            // ---------------------------------------------------------------- left page: the contents
            Parchment {
                id: leftPage
                z: 2
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
                z: 2
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

            // ---------------------------------------------------------------- opening: the leaves
            // the left page as its leaf's other side (and hidden until that leaf has landed)
            ShaderEffectSource {
                id: leftAsLeaf
                sourceItem: leftPage
                live: true
                hideSource: root.spread && !root.settled
                visible: false
            }
            Repeater {
                model: root.spread ? 2 : 0
                Flip {
                    required property int index
                    z: 3
                    visible: !root.settled && root.op > 0
                    x: book.spine; y: 10
                    width: root.pageW; height: root.pageH
                    angle: -180 * (index === 0 ? root.leaf1T : root.leaf2T)
                    // the first leaf over lies under the second
                    front: Parchment { gutter: -1; seed: 0.5 + index * 0.1 }
                    back: index === 0 ? blankBack : leafBack
                }
            }
            Component { id: blankBack; Parchment { gutter: 1; seed: 0.66 } }
            Component { id: leafBack; ShaderEffectSource { sourceItem: leftPage; live: true } }

            // ---------------------------------------------------------------- the front cover
            Flip {
                visible: root.spread
                z: root.coverT < 0.5 ? 4 : 1
                x: book.spine - 4; y: 0
                width: book.openW + 4; height: book.height
                angle: -180 * root.coverT
                // outside: leather, a gilt frame and the title
                front: Cover {
                    id: face
                    radius: 8
                    bevel: 12
                    wear: 0.65
                    seed: 0.44
                    light: Qt.vector3d(book.lamp.x - book.spine, book.lamp.y, book.lamp.z)
                    lightPower: 1.5
                    ambient: 0.85
                    Rectangle { x: 20; width: 3; height: face.height; color: face.blind }
                    Rectangle { x: 38; y: 26; width: face.width - 64; height: face.height - 52; color: "transparent"; border.width: 2.5; border.color: face.gilt }
                    Rectangle { x: 46; y: 34; width: face.width - 80; height: face.height - 68; color: "transparent"; border.width: 1.5; border.color: face.blind }
                    Repeater {
                        model: ["tl", "tr", "bl", "br"]
                        Flourish {
                            required property string modelData
                            corner: modelData
                            size: 70
                            color: face.gilt; shade: face.gilt; stroke: 2
                            x: modelData.endsWith("l") ? 50 : face.width - 38 - width
                            y: modelData.startsWith("t") ? 38 : face.height - 38 - height
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 8
                        spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Codex"; color: face.gilt; font.family: Theme.blackletter; font.pixelSize: 84 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "BEING THE BOOK OF THIS MACHINE"; color: face.gilt
                               font.family: Theme.caps; font.pixelSize: 13; font.letterSpacing: 3 }
                    }
                }
                // inside: the leather turned in round a pastedown
                back: Item {
                    Cover { anchors.fill: parent; radius: 8; bevel: 8; wear: 0.4; seed: 0.47; ambient: 0.6; lightPower: 0.9
                            light: Qt.vector3d(book.lamp.x, book.lamp.y, book.lamp.z) }
                    Parchment { anchors.fill: parent; anchors.margins: 18; radius: 2; color: Theme.pageDeep; age: 0.7; seed: 0.18 }
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
                z: 3
            }
            ShaderEffectSource {
                id: leftShot
                sourceItem: leftPage
                live: true
                visible: false
            }
            ShaderEffectSource {
                id: liveShot
                sourceItem: rightPage
                live: true
                hideSource: root.turning && root.leafDir < 0
                visible: false
            }
            // the back of a leaf: plain paper, bound on the right once it lies on the left
            Parchment {
                id: versoPage
                x: 14; y: 10
                width: root.pageW; height: root.pageH
                radius: 3; gutter: 1; seed: 0.57; age: 0.5
                visible: root.turning
            }
            ShaderEffectSource { id: versoShot; sourceItem: versoPage; hideSource: true; visible: false }
            Repeater {
                model: root.turning ? root.leaves : []
                Item {
                    id: leafSlot
                    required property var modelData
                    required property int index
                    readonly property var info: CodexState.pages[modelData.chapter] ?? CodexState.pages[0]
                    // stacking follows the leaf: unturned leaves lie in their stack, a leaf in the air
                    // is above every leaf lying down (the earlier one on top until it passes the
                    // middle, the later one after), and turned leaves stack up on the other side
                    readonly property real a: root.leafDir > 0 ? leaf : 1 - leaf
                    z: a <= 0 ? 100 - index : a >= 1 ? 200 + index : a < 0.5 ? 300 - index : 400 + index
                    x: 14; y: 10
                    width: root.pageW * 2
                    height: root.pageH
                    readonly property real leaf: root.leafAt(index)

                    // a chapter passed on the way: its first page, the heading alone
                    Item {
                        id: titlePage
                        visible: leafSlot.modelData.kind === "title"
                        width: root.pageW
                        height: root.pageH
                        Parchment { anchors.fill: parent; radius: 3; gutter: -1; seed: 0.83 + leafSlot.index * 0.07 }
                        Row {
                            x: 46; y: 30
                            spacing: 14
                            Initial { letter: leafSlot.info.title.charAt(0); size: 56 }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: leafSlot.info.title; color: Theme.ink; font.family: Theme.display; font.weight: Font.DemiBold; font.pixelSize: 30 }
                                Body { text: leafSlot.info.sub; italic: true; color: Theme.inkDim; font.pixelSize: 14 }
                            }
                        }
                        GoldRule { x: 46; y: 104; width: parent.width - 80; color: Theme.alpha(Theme.inkDim, 0.6); ornament: "❦" }
                        Body {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12
                            text: "— " + Theme.roman(leafSlot.modelData.chapter * 2 + 3).toLowerCase() + " —"
                            italic: true
                            color: Theme.inkDim
                            font.pixelSize: 13
                        }
                    }
                    // (drawn through a source that hides it: a hidden item's own shader layers never render)
                    ShaderEffectSource {
                        id: titleShot
                        sourceItem: titlePage
                        hideSource: true
                        visible: false
                    }
                    ShaderEffect {
                        anchors.fill: parent
                        property var source: leafSlot.modelData.kind === "old" ? oldShot : leafSlot.modelData.kind === "live" ? liveShot : titleShot
                        property var backSource: leftShot
                        property size size: Qt.size(width, height)
                        property real pageW: root.pageW
                        property real fold: root.pageW * (1 - leafSlot.leaf)
                        property real radius: root.pageW * 0.2 * Math.sin(Math.PI * leafSlot.leaf)
                        property real tilt: 0.3 * Math.sin(Math.PI * leafSlot.leaf)
                        property var versoSource: versoShot
                        // the leaf that ends up as the left page: forward the last to land, back the
                        // first to lift
                        property real backMix: root.leafDir > 0
                            ? (leafSlot.index === root.nLeaves - 1 ? Math.max(0, (leafSlot.leaf - 0.82) / 0.18) : 0)
                            : (leafSlot.index === 0 ? Math.max(0, 1 - (1 - leafSlot.leaf) / 0.18) : 0)
                        fragmentShader: Theme.shaders + "curl.frag.qsb"
                    }
                }
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
