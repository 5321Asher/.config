import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../utilities"

// The summoning circle: Grimoire's app launcher (SUPER + CTRL + Space), made as a thing rather than
// a light show. A disc of tooled leather (widgets/Cover.qml, lit from above): gilt rings, a band of
// runes and a heptagram pressed blind into it. On the star's seven points, brass medallions hold the
// seven likeliest programs; in the middle, in a brass ring, the scrying glass (shaders/scry.frag)
// shows the one you'd summon. Under the circle, the line you write on.
// Writing stirs the mist; ← → (or Tab) glide the medallions round to bring the next one to the top;
// Enter: the glass flares and the medallions make one smooth turn as it goes. Click a medallion to
// summon it. Nothing matching: Enter runs what you wrote as a command. Esc dismisses.
//   qs ipc call circle toggle | type <words> | cast
PanelWindow {
    id: root

    // Follows the focused monitor only while hidden (moving a shown window rebuilds its surface)
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
    Behavior on shown { NumberAnimation { duration: CircleState.open ? Theme.slow : Theme.normal; easing.type: Theme.easing } }

    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "circle") body.grabToImage(r => r.saveToFile(path)); }
    }

    // ---------------------------------------------------------------- the programs
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    readonly property int points: 7
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
            return apps.slice().sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name)).slice(0, points);
        return apps.map(a => ({ a: a, s: match(a, q) })).filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + boost(m.a) }))
            .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, points).map(m => m.a);
    }
    readonly property var chosen: results[pick] ?? null
    onQueryChanged: { setPick(0); if (visible) stirAnim.restart(); }
    onResultsChanged: if (pick >= results.length) setPick(0)

    FileView {
        id: usage
        path: Quickshell.statePath("circle-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }

    function iconFor(a) { return Quickshell.iconPath(a?.icon || "application-x-executable", "application-x-executable"); }

    // ---------------------------------------------------------------- the turning
    // The medallions sit on the star's points; `turn` (degrees) brings the chosen one to the top by
    // the shortest way round, gliding there.
    property real turn: 0
    Behavior on turn { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
    function setPick(i) {
        const n = points;
        let d = ((i - pick) % n + n) % n;
        if (d > n / 2) d -= n;
        pick = i;
        turn -= d * 360 / n;
    }
    // coming in, the medallions glide into place from a little way round
    property real arrive: 0
    NumberAnimation { id: arriveAnim; target: root; property: "arrive"; from: -40; to: 0; duration: 700; easing.type: Easing.OutCubic }

    // ---------------------------------------------------------------- casting
    function cast() {
        if (castAnim.running) return;
        const a = chosen;
        const q = query.trim();
        if (!a && !q) { CircleState.open = false; return; }
        castAnim.restart();
        if (a) {
            const counts = Object.assign({}, launches);
            counts[a.id] = (counts[a.id] ?? 0) + 1;
            launches = counts;
            usage.setText(JSON.stringify(launches));
            a.execute();
        } else Quickshell.execDetached(["sh", "-c", q]);
    }
    property real flare: 0
    property real spin: 0
    SequentialAnimation {
        id: castAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "spin"; from: 0; to: 360; duration: 620; easing.type: Easing.InOutCubic }
            SequentialAnimation {
                NumberAnimation { target: root; property: "flare"; from: 0; to: 1; duration: 260; easing.type: Easing.OutQuad }
                PauseAnimation { duration: 200 }
            }
        }
        ScriptAction { script: CircleState.open = false }
        PauseAnimation { duration: Theme.normal }
        ScriptAction { script: { root.flare = 0; root.spin = 0; } }
    }

    // the mist: its time, and a stir that settles after each thing you write
    property real time: 0
    FrameAnimation { running: root.visible; onTriggered: root.time += frameTime }
    property real stir: 0
    NumberAnimation { id: stirAnim; target: root; property: "stir"; from: 1; to: 0; duration: 1800; easing.type: Easing.OutCubic }

    // the program in the glass: it fades across when the choice changes
    property var inGlass: null
    onChosenChanged: glassSwap.restart()
    SequentialAnimation {
        id: glassSwap
        NumberAnimation { target: glassIcon; property: "opacity"; to: 0; duration: 80 }
        ScriptAction { script: root.inGlass = root.chosen }
        NumberAnimation { target: glassIcon; property: "opacity"; to: 1; duration: 200 }
    }

    Connections {
        target: CircleState
        function onTyped(text) { input.text = text; root.query = text; }
        function onCastRequested() { root.cast(); }
        function onOpenChanged() {
            if (CircleState.open) {
                castAnim.stop();
                root.flare = 0; root.spin = 0;
                root.query = "";
                root.pick = 0;
                input.text = "";
                input.forceActiveFocus();
                usage.reload();
                arriveAnim.restart();
            }
        }
    }

    // ---------------------------------------------------------------- geometry
    readonly property real dd: Math.round(Math.min(600, height * 0.6, width * 0.8))
    readonly property real rr: dd / 2
    readonly property real cy: height * 0.43
    readonly property real starR: rr * 0.63
    readonly property real medD: Math.round(dd * 0.15)
    readonly property real glassD: Math.round(dd * 0.36)
    // a light above and to the left of the circle, in the disc's coordinates
    readonly property vector3d lamp: Qt.vector3d(dd * 0.2, -dd * 0.35, dd * 1.3)

    Item {
        id: body
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.mix(Theme.veil, "#000000", 0.3), 0.6 * root.shown) }
        MouseArea { anchors.fill: parent; onClicked: CircleState.open = false }

        Item {
            id: stage
            anchors.fill: parent
            opacity: root.shown
            scale: 0.95 + 0.05 * root.shown

            // ------------------------------------------------------------ the disc
            Item {
                id: disc
                width: root.dd; height: root.dd
                x: (root.width - width) / 2
                y: root.cy - root.rr
                MouseArea { anchors.fill: parent; onClicked: {} }

                // its shadow on the desk
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 22; anchors.bottomMargin: -30; anchors.leftMargin: 8; anchors.rightMargin: -14
                    radius: width / 2
                    color: Qt.alpha("#000000", 0.6)
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
                }
                Cover {
                    id: plate
                    anchors.fill: parent
                    radius: width / 2
                    bevel: 18
                    wear: 0.6
                    seed: 0.35
                    color: Theme.mix(Theme.leatherDark, Theme.leather, 0.55)
                    light: root.lamp
                    lightPower: 1.3
                    ambient: 0.55
                    lightColor: Theme.mix(Theme.flame, "#ffffff", 0.5)

                    // gilt rings at the rim, a band of runes pressed blind between them
                    Rectangle { anchors.centerIn: parent; width: root.dd * 0.955; height: width; radius: width / 2; color: "transparent"; border.width: 2.2; border.color: plate.gilt }
                    Rectangle { anchors.centerIn: parent; width: root.dd * 0.925; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: plate.gilt }
                    Repeater {
                        model: 30
                        Text {
                            required property int index
                            readonly property real a: index / 30 * 2 * Math.PI - Math.PI / 2
                            x: root.rr + Math.cos(a) * root.rr * 0.845 - width / 2
                            y: root.rr + Math.sin(a) * root.rr * 0.845 - height / 2
                            rotation: index / 30 * 360
                            text: Theme.allRunes[(index * 7) % Theme.allRunes.length]
                            color: plate.blind
                            font.family: Theme.runic
                            font.pixelSize: root.dd * 0.04
                        }
                    }
                    Rectangle { anchors.centerIn: parent; width: root.dd * 0.77; height: width; radius: width / 2; color: "transparent"; border.width: 1.6; border.color: plate.gilt }
                    // the heptagram, pressed blind, its points under the medallions
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: plate.blind
                            strokeWidth: 3
                            fillColor: "transparent"
                            joinStyle: ShapePath.MiterJoin
                            PathSvg {
                                path: {
                                    let d = "";
                                    for (let k = 0; k <= 7; k++) {
                                        const a = -Math.PI / 2 + (k * 3 % 7) * 2 * Math.PI / 7;
                                        d += (k ? " L " : "M ") + (root.rr + Math.cos(a) * root.starR).toFixed(1) + " " + (root.rr + Math.sin(a) * root.starR).toFixed(1);
                                    }
                                    return d;
                                }
                            }
                        }
                    }
                    Rectangle { anchors.centerIn: parent; width: root.starR * 2; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: plate.blind }
                }

                // ------------------------------------------------------------ the medallions
                Repeater {
                    model: root.points
                    Item {
                        id: med
                        required property int index
                        readonly property var app: root.results[index] ?? null
                        readonly property bool here: index === root.pick
                        readonly property real a: (-90 + index * 360 / root.points + root.turn + root.arrive + root.spin) * Math.PI / 180
                        width: root.medD; height: root.medD
                        x: root.rr + Math.cos(a) * root.starR - width / 2
                        y: root.rr + Math.sin(a) * root.starR - height / 2
                        scale: here ? 1.12 : 1
                        // no program for this point: it sinks away
                        opacity: app ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            anchors.topMargin: 4
                            radius: width / 2
                            color: Qt.alpha("#000000", 0.55)
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 16 }
                        }
                        // a breath of arcane light round the chosen one
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -5
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.arcane
                            opacity: med.here ? 0.7 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                            layer.enabled: true
                            layer.effect: MultiEffect { blurEnabled: true; blur: 0.5; blurMax: 12 }
                        }
                        Cover {
                            anchors.fill: parent
                            radius: width / 2
                            bevel: width * 0.16
                            metal: true
                            wear: 0.35
                            seed: 0.2 + med.index * 0.07
                            light: Qt.vector3d(root.lamp.x - med.x, root.lamp.y - med.y, root.lamp.z)
                            lightPower: 1.2
                            ambient: 0.5
                        }
                        // the well, and the program in it
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.74; height: width
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.alpha("#000000", 0.85) }
                                GradientStop { position: 1; color: Theme.mix(Theme.leatherDark, "#000000", 0.4) }
                            }
                            Image {
                                anchors.centerIn: parent
                                width: parent.width * 0.62; height: width
                                sourceSize: Qt.size(96, 96)
                                source: med.app ? root.iconFor(med.app) : ""
                                visible: !!med.app
                                opacity: med.here ? 1 : 0.8
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !!med.app
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.setPick(med.index); root.cast(); }
                        }
                    }
                }

                // ------------------------------------------------------------ the glass
                Cover {
                    id: glassRing
                    width: root.glassD + 20; height: width
                    anchors.centerIn: parent
                    radius: width / 2
                    bevel: 8
                    metal: true
                    wear: 0.3
                    seed: 0.58
                    light: Qt.vector3d(root.lamp.x - x, root.lamp.y - y, root.lamp.z)
                    lightPower: 1.2
                    ambient: 0.5
                    Rectangle { anchors.fill: parent; anchors.margins: 4; radius: width / 2; color: "transparent"; border.width: 1.2; border.color: glassRing.blind }
                }
                ShaderEffect {
                    id: glass
                    width: root.glassD; height: width
                    anchors.centerIn: parent
                    property real time: root.time
                    property real stir: root.stir
                    property real flare: root.flare
                    property real px: width
                    property color arcane: Theme.arcane
                    property color gold: Theme.goldBright
                    property color glass: Theme.mix(Theme.leatherDark, "#000000", 0.6)
                    fragmentShader: Theme.shaders + "scry.frag.qsb"
                }
                Image {
                    id: glassIcon
                    anchors.centerIn: glass
                    width: root.glassD * 0.42; height: width
                    sourceSize: Qt.size(192, 192)
                    source: root.inGlass ? root.iconFor(root.inGlass) : ""
                    visible: !!root.inGlass
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.arcane; shadowOpacity: 0.5; shadowBlur: 0.8
                                                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 32 }
                }
                Text {
                    visible: !root.inGlass && root.query.trim() !== ""
                    anchors.centerIn: glass
                    text: "\u{f018d}"
                    color: Theme.alpha(Theme.gold, 0.8)
                    font.family: Theme.glyphs
                    font.pixelSize: root.glassD * 0.3
                }
            }

            // ------------------------------------------------------------ the line to write on
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: disc.y + disc.height + 30
                width: Math.min(560, root.width - 60)
                spacing: 6

                Item {
                    width: parent.width
                    height: 40
                    TextInput {
                        id: input
                        anchors.horizontalCenter: parent.horizontalCenter
                        // empty, the caret waits at the start of the placeholder
                        anchors.horizontalCenterOffset: text === "" ? -placeholder.width / 2 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(contentWidth + 4, 2)
                        color: Theme.goldBright
                        selectionColor: Theme.alpha(Theme.gold, 0.4)
                        font.family: Theme.body
                        font.italic: true
                        font.pixelSize: 28
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
                            const n = Math.max(1, root.results.length);
                            if (e.key === Qt.Key_Escape) CircleState.open = false;
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.cast();
                            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) root.setPick((root.pick + 1) % n);
                            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) root.setPick((root.pick - 1 + n) % n);
                            else return;
                            e.accepted = true;
                        }
                    }
                    Body {
                        id: placeholder
                        visible: input.text === ""
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 6
                        text: "speak a name…"
                        italic: true
                        color: Theme.alpha(Theme.dim, 0.65)
                        font.pixelSize: 26
                    }
                }
                GoldRule { width: parent.width; color: Theme.alpha(Theme.gold, 0.6); ornament: "◆" }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.chosen ? root.chosen.name : root.query.trim() ? "Run “" + root.query.trim() + "”" : ""
                    color: Theme.goldBright
                    font.family: Theme.display; font.weight: Font.DemiBold
                    font.pixelSize: 24
                }
                Body {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.chosen ? (root.chosen.comment || root.chosen.genericName || "") : root.query.trim() ? "nothing answers: it will run as a command" : ""
                    italic: true
                    color: Theme.alpha(Theme.dim, 0.75)
                    font.pixelSize: 14
                }
                Item { width: 1; height: 14 }
                Caps {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "← →  turn   ·   enter  summons   ·   esc  dismisses"
                    color: Theme.alpha(Theme.gold, 0.45)
                    font.pixelSize: 10
                    font.letterSpacing: 3
                }
            }
        }
    }
}
