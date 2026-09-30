import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../launcher"
import "../utilities"

// The arcana: Grimoire's root menu (ContentsState holds what's in it). The screen sinks into a
// candlelit dark with smoke drifting through it (shaders/veil.frag) and the cards rise into a fan,
// one after another. The pointer lifts a card and its gilt catches the light; drawing one
// either does its thing or turns it over: it spins edge-on in the middle of the screen and its back
// opens into the reading, the card's menu on a parchment leaf, one level at a time.
//   ← → choose · Enter draws · 1–9 draw that card · Esc goes back
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden (moving a shown window rebuilds its surface)
    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: ContentsState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-arcana"
    WlrLayershell.keyboardFocus: ContentsState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: ContentsState.open ? null : noInput
    Region { id: noInput }

    property real shown: ContentsState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: ContentsState.open ? Theme.slow : Theme.normal; easing.type: Theme.easing } }
    onVisibleChanged: if (visible) keys.forceActiveFocus()

    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "arcana") keys.grabToImage(r => r.saveToFile(path)); }
    }

    // ---------------------------------------------------------------- the spread's geometry
    readonly property var cards: ContentsState.cards
    readonly property int n: cards.length
    readonly property real cardW: Math.round(Math.min(210, width / 8, height / 4.4))
    readonly property real cardH: Math.round(cardW * 1.68)
    readonly property real pitch: n < 2 ? 0 : Math.min(cardW * 1.06, (width - 120 - cardW) / (n - 1))
    readonly property real cy: height * 0.5
    // turning a card over: 0 = the spread, 1 = the reading open (first half: the card goes edge-on
    // in the middle; second half: its back opens out)
    property real turn: ContentsState.reading >= 0 ? 1 : 0
    Behavior on turn { NumberAnimation { duration: 560; easing.type: Easing.InOutSine } }
    readonly property real half1: Math.min(1, turn * 2)
    // the card that is (or was) turned over: kept until it has flipped back and gone home to the fan
    property int turned: -1
    Connections {
        target: ContentsState
        function onReadingChanged() { if (ContentsState.reading >= 0) root.turned = ContentsState.reading; }
    }
    onTurnChanged: if (turn === 0 && ContentsState.reading < 0) turned = -1
    readonly property real half2: Math.max(0, turn * 2 - 1)

    // deal the cards each time the arcana opens
    property int dealt: 0
    Connections {
        target: ContentsState
        function onOpenChanged() { if (ContentsState.open) { root.dealt = 0; dealer.restart(); } }
        function onCardsChanged() { if (ContentsState.open) { root.dealt = 0; dealer.restart(); } }
    }
    Timer { id: dealer; interval: 55; repeat: true; onTriggered: if (++root.dealt >= root.n) stop() }

    // the veil's time (only runs while it's up)
    property real time: 0
    FrameAnimation { running: root.visible; onTriggered: root.time += frameTime }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true

        HoverHandler { id: hover }

        // ---------------------------------------------------------------- the veil
        Item {
            anchors.fill: parent
            opacity: root.shown
            // drawn at half size and scaled up: smoke is soft anyway
            ShaderEffect {
                width: parent.width / 2
                height: parent.height / 2
                scale: 2
                transformOrigin: Item.TopLeft
                property size size: Qt.size(width, height)
                property real time: root.time
                property point pool: Qt.point(0.5, 0.5)
                property color dark: Theme.mix(Theme.veil, "#000000", 0.35)
                property color warm: Theme.flame
                property color arcane: Theme.arcane
                fragmentShader: Theme.shaders + "veil.frag.qsb"
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: ContentsState.reading >= 0 ? ContentsState.back() : ContentsState.close()
        }

        // ---------------------------------------------------------------- the spread
        Repeater {
            model: root.cards
            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property real t: index - (root.n - 1) / 2
                readonly property bool chosen: ContentsState.sel === index
                readonly property bool isReading: root.turned === index
                readonly property bool isDealt: index < root.dealt

                // where it lies in the fan (lifted when chosen), and where it goes when turned over
                readonly property real fanX: root.width / 2 + t * root.pitch - root.cardW / 2
                readonly property real fanY: root.cy - root.cardH / 2 + t * t * 7 - (chosen ? 34 : 0)
                readonly property real fanR: t * 3.5 * (chosen ? 0.35 : 1)
                property real deal: isDealt && ContentsState.open ? 1 : 0
                Behavior on deal { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
                property real lift: chosen ? 1 : 0
                Behavior on lift { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

                width: root.cardW
                height: root.cardH
                x: isReading ? fanX + (root.width / 2 - root.cardW / 2 - fanX) * root.half1 : fanX
                y: (isReading ? fanY + (root.cy - root.cardH / 2 - fanY) * root.half1 : fanY + 90 * root.turn)
                   + (1 - deal) * (root.height * 0.6)
                rotation: (isReading ? fanR * (1 - root.half1) : fanR) + (1 - deal) * t * 6
                scale: 1 + 0.05 * lift
                opacity: Math.min(1, deal * 1.5) * (isReading ? 1 : 1 - root.turn) * (chosen || ContentsState.reading >= 0 ? 1 : 0.82)
                visible: opacity > 0.01 && !(isReading && root.half1 >= 1)
                z: chosen ? 10 : 0
                transform: Rotation {
                    origin.x: slot.width / 2
                    origin.y: slot.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: slot.isReading ? 90 * root.half1 : 0
                }
                Behavior on y { enabled: root.turn === 0 && slot.deal >= 1; NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

                Card {
                    anchors.fill: parent
                    card: slot.modelData
                    chosen: slot.chosen
                    light: slot.chosen && hover.hovered
                        ? Qt.point((hover.point.position.x - slot.x) / slot.width, (hover.point.position.y - slot.y) / slot.height)
                        : Qt.point(0.3, 0.15)
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: ContentsState.reading < 0 && root.turn === 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: ContentsState.sel = slot.index
                    onClicked: ContentsState.draw(slot.index)
                }
            }
        }

        // what you can do, under the spread
        Caps {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.cy + root.cardH / 2 + 70
            opacity: root.shown * (1 - root.turn) * 0.8
            text: "← →  choose   ·   enter  draws   ·   esc  leaves"
            color: Theme.goldDeep
            font.pixelSize: 11
            font.letterSpacing: 3
        }

        // ---------------------------------------------------------------- the reading
        Reading {
            id: reading
            readonly property real w: Math.min(480, root.width - 60)
            // as tall as its entries need
            readonly property var items: ContentsState.stack[ContentsState.stack.length - 1]?.items ?? []
            readonly property real need: 190 + Math.max(3, items.length) * 2 + items.reduce((a, it) => a + ((it.sub_text ?? "") !== "" ? 54 : 42), 0)
            property real h: Math.min(660, root.height - 140, Math.max(340, need))
            Behavior on h { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
            width: root.cardW + (w - root.cardW) * root.half2
            height: root.cardH + (h - root.cardH) * root.half2
            x: (root.width - width) / 2
            y: root.cy - height / 2
            visible: root.half2 > 0
            card: ContentsState.cards[root.turned] ?? ({})
            open: root.half2 >= 1
            transform: Rotation {
                origin.x: reading.width / 2
                origin.y: reading.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: -90 * (1 - root.half2)
            }
        }

        // ---------------------------------------------------------------- the keys
        Keys.onPressed: e => {
            const k = e.key;
            if (ContentsState.reading >= 0) {
                const lv = ContentsState.stack[ContentsState.stack.length - 1];
                const items = lv?.items ?? [];
                const sel = lv?.sel ?? 0;
                if (k === Qt.Key_Down || k === Qt.Key_Tab) ContentsState.setSel((sel + 1) % Math.max(1, items.length));
                else if (k === Qt.Key_Up || k === Qt.Key_Backtab) ContentsState.setSel((sel - 1 + items.length) % Math.max(1, items.length));
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Right || k === Qt.Key_Space) ContentsState.choose(sel);
                else if (k === Qt.Key_Escape || k === Qt.Key_Left || k === Qt.Key_Backspace) ContentsState.back();
                else if (e.text && /\S/.test(e.text)) {
                    const ch = e.text.toLowerCase();
                    for (let s = 1; s <= items.length; s++) {
                        const i = (sel + s) % items.length;
                        if ((items[i].text ?? "").toLowerCase().startsWith(ch)) { ContentsState.setSel(i); break; }
                    }
                } else return;
            } else {
                const n = root.n;
                if (k === Qt.Key_Right || k === Qt.Key_Tab) ContentsState.sel = (ContentsState.sel + 1) % Math.max(1, n);
                else if (k === Qt.Key_Left || k === Qt.Key_Backtab) ContentsState.sel = (ContentsState.sel - 1 + n) % Math.max(1, n);
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Up || k === Qt.Key_Down) ContentsState.draw(ContentsState.sel);
                else if (k === Qt.Key_Escape) ContentsState.close();
                else if (k >= Qt.Key_1 && k <= Qt.Key_9) ContentsState.draw(k - Qt.Key_1);
                else if (e.text && /\S/.test(e.text)) {
                    const ch = e.text.toLowerCase();
                    for (let s = 1; s <= n; s++) {
                        const i = (ContentsState.sel + s) % n;
                        if ((root.cards[i].title ?? "").toLowerCase().startsWith(ch)) { ContentsState.sel = i; break; }
                    }
                } else return;
            }
            e.accepted = true;
        }
    }
}
