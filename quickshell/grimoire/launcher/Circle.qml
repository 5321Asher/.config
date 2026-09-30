import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../utilities"

// The seal-book: Grimoire's app launcher (SUPER + CTRL + Space). A plain search, and under it the
// seal of the program you're on, drawn out in ink as you choose it. Every program has its own seal
// and every part of it means something (launcher/seal.js): the sigil in the middle says what kind of
// program it is, the signs round it what it does, the tick band counts its name's letters, and a
// seal you summon often is drawn with more rings. Enter closes the ring: the seal glows and the
// program is summoned. ↑ ↓ choose, Esc dismisses; nothing matching, Enter runs what you wrote.
// (Its IPC is still `circle`, as setup.toml and older notes call it.)
//   qs ipc call circle toggle | type <words> | cast
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    visible: CircleState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-circle"
    WlrLayershell.keyboardFocus: CircleState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: CircleState.open ? null : noInput
    Region { id: noInput }

    property real shown: CircleState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: CircleState.open ? Theme.normal : Theme.fast; easing.type: Theme.easing } }

    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "circle") body.grabToImage(r => r.saveToFile(path)); }
    }

    // ---------------------------------------------------------------- the programs
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    readonly property int rows: 7
    property string query: ""
    property int pick: 0
    property var launches: ({})

    function match(a, q) {
        const name = a.name.toLowerCase();
        if (name.startsWith(q)) return 100 - name.length * 0.1;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (q.length < 2) return 0;
        if (name.includes(q)) return 60;
        if (q.length < 3) return 0;
        const more = [a.genericName ?? "", (a.keywords ?? []).join(" "), a.comment ?? "", a.id ?? ""].join(" ").toLowerCase();
        return more.includes(q) ? 40 : 0;
    }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        const boost = a => Math.min(45, 9 * Math.log2(1 + (launches[a.id] ?? 0)));
        if (q === "")
            return apps.slice().sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name)).slice(0, rows);
        return apps.map(a => ({ a: a, s: match(a, q) })).filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + boost(m.a) }))
            .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, rows).map(m => m.a);
    }
    readonly property var chosen: results[pick] ?? null
    onQueryChanged: pick = 0
    onResultsChanged: if (pick >= results.length) pick = 0

    // the seal follows the choice a moment later, so typing quickly doesn't restart it on every key
    property var sealed: null
    onChosenChanged: settle.restart()
    Timer { id: settle; interval: 90; onTriggered: root.sealed = root.chosen }

    FileView {
        id: usage
        path: Quickshell.statePath("circle-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }

    function iconFor(a) { return Quickshell.iconPath(a?.icon || "application-x-executable", "application-x-executable"); }

    // ---------------------------------------------------------------- casting
    property bool casting: false
    function cast() {
        if (casting) return;
        const a = chosen;
        const q = query.trim();
        if (!a && !q) { CircleState.open = false; return; }
        if (a) {
            settle.stop();
            root.sealed = a;
            const counts = Object.assign({}, launches);
            counts[a.id] = (counts[a.id] ?? 0) + 1;
            launches = counts;
            usage.setText(JSON.stringify(launches));
            a.execute();
            casting = true;
            castAnim.restart();
        } else {
            Quickshell.execDetached(["sh", "-c", q]);
            CircleState.open = false;
        }
    }
    // the ring closes and the seal glows (the program is already starting), then it's gone
    SequentialAnimation {
        id: castAnim
        PropertyAction { target: seal; property: "drawn"; value: 1 }
        PauseAnimation { duration: 480 }
        ScriptAction { script: CircleState.open = false }
        PauseAnimation { duration: Theme.normal }
        ScriptAction { script: root.casting = false }
    }

    Connections {
        target: CircleState
        function onTyped(text) { input.text = text; root.query = text; }
        function onCastRequested() { root.cast(); }
        function onOpenChanged() {
            if (CircleState.open) {
                castAnim.stop();
                root.casting = false;
                root.query = "";
                root.pick = 0;
                input.text = "";
                input.forceActiveFocus();
                usage.reload();
                root.sealed = null;
                settle.restart();
            }
        }
    }

    // ---------------------------------------------------------------- what the seal says
    readonly property var elementWords: ({ fire: "fire", water: "water", wind: "wind", earth: "earth", light: "light" })
    readonly property var elementMeaning: ({ fire: "a thing for making", water: "a thing for reaching others", wind: "a thing of sound and sight",
                                             earth: "a thing of the ground beneath", light: "a thing for reading and learning" })
    function reading(s) {
        if (!s) return "";
        const n = ["", "one", "two", "three", "four", "five", "six", "seven", "eight"][s.fold] ?? String(s.fold);
        return root.elementMeaning[s.element] + " · " + n + "-fold"
            + (s.rings >= 3 ? " · thrice-ringed: an old friend" : s.rings === 2 ? " · twice-ringed: well used" : "");
    }

    Item {
        id: body
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.mix(Theme.veil, "#000000", 0.3), 0.6 * root.shown) }
        MouseArea { anchors.fill: parent; onClicked: CircleState.open = false }

        Column {
            id: stack
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(30, (root.height - height) * 0.38) - (1 - root.shown) * 16
            spacing: 18
            opacity: root.shown

            // ------------------------------------------------------------ the search
            Item {
                id: card
                width: Math.min(600, root.width - 48)
                height: 78 + list.height + 20
                MouseArea { anchors.fill: parent }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 12; anchors.bottomMargin: -20; anchors.leftMargin: 3; anchors.rightMargin: -8
                    radius: 14
                    color: Qt.alpha("#000000", 0.55)
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 }
                }
                Cover {
                    id: frame
                    anchors.fill: parent
                    radius: 12; bevel: 9; wear: 0.5; seed: 0.47
                    color: Theme.leather
                    light: Qt.vector3d(width * 0.25, -height * 0.4, 700)
                    lightPower: 1.2; ambient: 0.62
                    lightColor: Theme.mix(Theme.flame, "#ffffff", 0.55)
                    Rectangle { anchors.fill: parent; anchors.margins: 8; radius: 7; color: "transparent"; border.width: 1.3; border.color: frame.gilt }
                }

                Item {
                    id: line
                    x: 30
                    width: parent.width - 60
                    height: 70
                    Text {
                        id: quill
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✦"
                        color: Theme.gold
                        font.family: Theme.symbols
                        font.pixelSize: 15
                    }
                    TextInput {
                        id: input
                        anchors.left: quill.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.goldBright
                        selectionColor: Theme.alpha(Theme.gold, 0.4)
                        font.family: Theme.body
                        font.italic: true
                        font.pixelSize: 24
                        focus: true
                        cursorDelegate: Rectangle {
                            width: 2
                            color: Theme.gold
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.15; duration: 650; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                            }
                        }
                        onTextEdited: root.query = text
                        Keys.onPressed: e => {
                            const n = root.results.length;
                            if (e.key === Qt.Key_Escape) CircleState.open = false;
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.cast();
                            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) root.pick = n ? (root.pick + 1) % n : 0;
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) root.pick = n ? (root.pick - 1 + n) % n : 0;
                            else return;
                            e.accepted = true;
                        }
                        Body {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Summon…"
                            italic: true
                            color: Theme.alpha(Theme.dim, 0.7)
                            font.pixelSize: 24
                        }
                    }
                }
                GoldRule { x: 24; y: line.height; width: parent.width - 48; color: Theme.alpha(Theme.gold, 0.55); ornament: "◆" }

                ListView {
                    id: list
                    x: 16
                    y: line.height + 12
                    width: parent.width - 32
                    height: Math.max(1, count) * 46
                    interactive: false
                    model: root.results.length ? root.results : root.query.trim() ? [null] : []
                    currentIndex: root.pick
                    highlightMoveDuration: Theme.fast
                    highlight: Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.alpha(Theme.gold, 0.18) }
                                GradientStop { position: 1; color: Theme.alpha(Theme.gold, 0.02) }
                            }
                        }
                        Rectangle { width: 2; height: parent.height - 14; anchors.verticalCenter: parent.verticalCenter; color: Theme.gold }
                    }
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool here: ListView.isCurrentItem
                        width: list.width
                        height: 46
                        Image {
                            id: icon
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28
                            sourceSize: Qt.size(56, 56)
                            source: row.modelData ? root.iconFor(row.modelData) : ""
                            visible: !!row.modelData
                        }
                        Text {
                            visible: !row.modelData
                            anchors.centerIn: icon
                            text: "\u{f018d}"
                            color: Theme.gold
                            font.family: Theme.glyphs
                            font.pixelSize: 20
                        }
                        Body {
                            id: name
                            x: 58
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width - x - 20)
                            elide: Text.ElideRight
                            text: row.modelData ? row.modelData.name : "Run “" + root.query.trim() + "”"
                            color: row.here ? Theme.goldBright : Theme.fg
                            font.pixelSize: 18
                        }
                        Body {
                            anchors.left: name.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.baseline: name.baseline
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            text: row.modelData ? (row.modelData.genericName || row.modelData.comment || "") : "as a command"
                            italic: true
                            color: Theme.alpha(Theme.dim, row.here ? 0.9 : 0.6)
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: root.pick = row.index
                            onClicked: { root.pick = row.index; root.cast(); }
                        }
                    }
                }
                Body {
                    visible: list.count === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: list.y + 12
                    text: "nothing answers"
                    italic: true
                    color: Theme.alpha(Theme.dim, 0.6)
                }
            }

            // ------------------------------------------------------------ the seal
            Item {
                id: leaf
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real d: Math.max(200, Math.min(340, root.height - card.height - 190))
                width: d + 80
                height: d + 96
                visible: !!root.sealed || root.casting
                MouseArea { anchors.fill: parent }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 10; anchors.bottomMargin: -16; anchors.leftMargin: 3; anchors.rightMargin: -7
                    radius: 6
                    color: Qt.alpha("#000000", 0.5)
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 32 }
                }
                Parchment { anchors.fill: parent; radius: 4; age: 0.55; seed: 0.74 }

                SealView {
                    id: seal
                    x: 40; y: 26
                    width: leaf.d; height: leaf.d
                    app: root.sealed
                    uses: root.sealed ? (root.launches[root.sealed.id] ?? 0) : 0
                    closed: root.casting
                    ink: Theme.mix(Theme.ink, Theme.rubric, 0.12)
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: seal.y + seal.height + 10
                    width: parent.width - 30
                    spacing: 1
                    Caps {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: seal.seal ? "sigil of " + root.elementWords[seal.seal.element] + "   ·   " + seal.seal.signs.join(" · ") : ""
                        color: Theme.rubric
                        font.pixelSize: 11
                        font.letterSpacing: 2.5
                    }
                    Body {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.reading(seal.seal)
                        italic: true
                        color: Theme.inkDim
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
