import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../utilities"

// The summoning circle: Grimoire's app launcher (SUPER + CTRL + Space). A circle of gold appears in
// the middle of the screen over a veil: an outer band of runes turning slowly, a heptagram with the
// seven likeliest programs on its points, and in the centre the one you'd summon. As you type, each
// letter is inscribed round the inner ring as a glowing rune (Theme.futhark) with a puff of sparks.
// Tab / arrows turn the star to the next program; Enter casts: the circle ignites, spins faster and
// faster, and collapses into the new window as it opens (it waits for Hyprland to say where), with a
// flash. Nothing matching? Enter casts what you wrote as a command. Esc dispels it.
//   qs ipc call circle toggle
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: (CircleState.open || casting || shown > 0.01) && !spent
    // a finished cast hides at once (the veil mustn't fade back in after the collapse)
    property bool spent: false

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-circle"
    WlrLayershell.keyboardFocus: CircleState.open && !casting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // while casting, the new window must get the clicks and the keyboard
    mask: casting ? noInput : null
    Region { id: noInput }

    property real shown: CircleState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: CircleState.open ? Theme.slow : Theme.normal; easing.type: Theme.easing } }

    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "circle") body.grabToImage(r => r.saveToFile(path)); }
    }

    // ---------------------------------------------------------------- the programs
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
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
            return apps.slice().sort((a, b) => boost(b) - boost(a) || a.name.localeCompare(b.name)).slice(0, 7);
        return apps.map(a => ({ a: a, s: match(a, q) })).filter(m => m.s > 0)
            .map(m => Object.assign(m, { s: m.s + boost(m.a) }))
            .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name)).slice(0, 7).map(m => m.a);
    }
    readonly property var chosen: results[pick] ?? null
    onQueryChanged: pick = 0
    onResultsChanged: if (pick >= results.length) pick = 0

    FileView {
        id: usage
        path: Quickshell.statePath("circle-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }

    function iconFor(a) { return Quickshell.iconPath(a?.icon || "application-x-executable", "application-x-executable"); }

    // ---------------------------------------------------------------- casting
    property bool casting: false
    property real ignite: 0            // 0..1: the flare
    property real spin: 0              // degrees, while casting
    property real spinSpeed: 0         // degrees per second
    property real collapse: 0          // 0..1: shrinking into the target
    property real flash: 0             // 0..1: the burst at the end
    property point target: Qt.point(width / 2, cy)
    property bool targetKnown: false
    property string awaiting: ""       // "" or "any": waiting for a window to open

    function cast() {
        if (casting) return;
        const a = chosen;
        const q = query.trim();
        if (!a && !q) { CircleState.open = false; return; }
        if (a) {
            const counts = Object.assign({}, launches);
            counts[a.id] = (counts[a.id] ?? 0) + 1;
            launches = counts;
            usage.setText(JSON.stringify(launches));
            a.execute();
        } else Quickshell.execDetached(["sh", "-c", q]);
        casting = true;
        targetKnown = false;
        target = Qt.point(width / 2, cy);
        awaiting = "any";
        sparks.burst(width / 2, cy, 60);
        igniteAnim.restart();
        giveUp.restart();
    }
    FrameAnimation {
        running: root.casting
        onTriggered: {
            root.spinSpeed = Math.min(1100, root.spinSpeed + frameTime * 900);
            root.spin += root.spinSpeed * frameTime;
        }
    }
    SequentialAnimation {
        id: igniteAnim
        NumberAnimation { target: root; property: "ignite"; from: 0; to: 1; duration: 340; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 420 }
        ScriptAction { script: if (root.targetKnown) collapseAnim.restart(); }
    }
    // if no window turns up (a command, an app that's already open, a slow start), collapse anyway
    Timer { id: giveUp; interval: 1700; onTriggered: if (root.casting && !collapseAnim.running && root.flash === 0) collapseAnim.restart() }
    SequentialAnimation {
        id: collapseAnim
        ScriptAction { script: root.awaiting = "" }
        NumberAnimation { target: root; property: "collapse"; from: 0; to: 1; duration: 560; easing.type: Easing.InCubic }
        ScriptAction { script: sparks.burst(root.target.x, root.target.y, 90) }
        NumberAnimation { target: root; property: "flash"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
        ScriptAction { script: root.finish() }
    }
    function finish() {
        CircleState.open = false;
        casting = false;
        giveUp.stop();
        spent = true;
        ignite = 0; spin = 0; spinSpeed = 0; collapse = 0; flash = 0;
    }

    // Where the new window opened: Hyprland announces it, then we look up its box
    property string newAddress: ""
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (!root.casting || root.awaiting === "" || e.name !== "openwindow") return;
            root.newAddress = e.data.split(",")[0];
            Hyprland.refreshToplevels();
            locate.restart();
        }
    }
    Timer {
        id: locate
        interval: 140
        property int tries: 0
        onTriggered: {
            const addr = root.newAddress.replace(/^0x/, "");
            const t = Hyprland.toplevels.values.find(w => (w.address ?? "").replace(/^0x/, "") === addr);
            const o = t?.lastIpcObject ?? {};
            if (o.at && o.size && o.size[0] > 0) {
                root.target = Qt.point(o.at[0] - (root.screen?.x ?? 0) + o.size[0] / 2, o.at[1] - (root.screen?.y ?? 0) + o.size[1] / 2);
                root.targetKnown = true;
                tries = 0;
                if (!igniteAnim.running && !collapseAnim.running) collapseAnim.restart();
            } else if (tries++ < 6) { Hyprland.refreshToplevels(); restart(); }
        }
    }

    Connections {
        target: CircleState
        function onTyped(text) { keys.text = text; root.query = text; }
        function onCastRequested() { root.cast(); }
        function onOpenChanged() {
            if (CircleState.open) {
                if (root.casting) root.finish();
                root.spent = false;
                root.query = "";
                root.pick = 0;
                keys.text = "";
                keys.forceActiveFocus();
                usage.reload();
            }
        }
    }

    // ---------------------------------------------------------------- geometry
    readonly property real cy: height * 0.47
    readonly property real rad: Math.min(290, height * 0.3, width * 0.4)
    readonly property real starR: rad * 0.6
    readonly property real runeR: rad * 0.8
    readonly property var runes: Array.from(query).map(c => Theme.rune(c))
    readonly property real runeStep: runes.length <= 12 ? 30 : 356 / runes.length
    // the star turns so the chosen program sits at the top
    property real starTurn: -pick * 360 / 7
    Behavior on starTurn { RotationAnimation { duration: Theme.slow; easing.type: Easing.OutBack; direction: RotationAnimation.Shortest } }

    // slow idle motion
    property real drift: 0
    NumberAnimation on drift { running: root.visible; from: 0; to: 360; duration: 120000; loops: Animation.Infinite }

    Item {
        id: body
        anchors.fill: parent

        // ---------------------------------------------------------------- the veil
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.veil, 0.5 * root.shown * (1 - root.collapse * 0.9))
        }
        Shape {
            anchors.fill: parent
            opacity: root.shown * (1 - root.collapse)
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: root.width / 2; centerY: root.cy; centerRadius: Math.max(root.width, root.height) * 0.7
                    focalX: root.width / 2; focalY: root.cy
                    GradientStop { position: 0; color: Theme.alpha(Theme.arcane, 0.08 + 0.1 * root.ignite) }
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1; color: Theme.alpha("#000000", 0.55) }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }
        MouseArea { anchors.fill: parent; enabled: !root.casting; onClicked: CircleState.open = false }

        Sparks {
            id: sparks
            anchors.fill: parent
            running: root.shown > 0.5 && !root.casting
            rate: 10 + root.runes.length * 2
            ringX: root.width / 2
            ringY: root.cy
            ringR: root.rad * 0.98
            opacity: 1 - root.flash * 0.3
        }

        // ---------------------------------------------------------------- the circle
        Item {
            id: circle
            width: root.rad * 2
            height: root.rad * 2
            x: root.width / 2 - root.rad + (root.target.x - root.width / 2) * root.collapse
            y: root.cy - root.rad + (root.target.y - root.cy) * root.collapse
            opacity: Math.min(1, root.shown * 1.4) * (1 - Math.max(0, root.collapse - 0.85) / 0.15)
            scale: (0.82 + 0.18 * root.shown) * (1 - root.collapse * 0.96)
            rotation: root.spin

            MouseArea { anchors.fill: parent; enabled: !root.casting }     // clicks on the circle don't dispel it

            ShaderEffect {
                anchors.centerIn: parent
                width: root.rad * 2.4
                height: root.rad * 2.4
                property real time: root.drift * 2
                property real power: Math.min(1, 0.25 + root.runes.length / 10)
                property real ignite: root.ignite
                property color arcane: Theme.arcane
                property color gold: Theme.goldBright
                fragmentShader: Theme.shaders + "aura.frag.qsb"
            }

            // the rings
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                readonly property color line: Theme.mix(Theme.gold, Theme.goldBright, root.ignite)
                layer.enabled: true
                layer.samples: 4
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.ignite > 0 ? Theme.goldBright : Theme.gold
                    shadowBlur: 0.5 + root.ignite * 0.5
                    shadowOpacity: 0.5 + root.ignite * 0.5
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    blurMax: 24
                }
                Ring { r: root.rad - 1; w: 2 }
                Ring { r: root.rad - 30; w: 1.2 }
                Ring { r: root.rad - 36; w: 0.8 }
                Ring { r: root.runeR - 20; w: 0.8; c: Theme.alpha(Theme.arcane, 0.7 + 0.3 * root.ignite) }
                Ring { r: root.rad * 0.34; w: 1.4 }
                Ring { r: root.rad * 0.34 - 6; w: 0.8 }
            }

            // the outer band of runes, turning slowly
            Item {
                anchors.fill: parent
                rotation: root.drift
                Repeater {
                    model: 36
                    Text {
                        required property int index
                        readonly property real a: index * 10 * Math.PI / 180
                        x: root.rad + Math.cos(a) * (root.rad - 15) - width / 2
                        y: root.rad + Math.sin(a) * (root.rad - 15) - height / 2
                        rotation: index * 10 + 90
                        text: Theme.allRunes[index % Theme.allRunes.length]
                        color: Theme.alpha(Theme.mix(Theme.gold, Theme.goldBright, root.ignite), 0.75 + 0.25 * root.ignite)
                        font.family: Theme.runic
                        font.pixelSize: 15
                    }
                }
            }
            // the four elements at the quarters, on little discs
            Repeater {
                model: [["🜂", 0], ["🜄", 90], ["🜁", 180], ["🜃", 270]]
                Item {
                    required property var modelData
                    readonly property real a: (modelData[1] - 90 - root.drift * 0.5) * Math.PI / 180
                    x: root.rad + Math.cos(a) * root.rad - 15
                    y: root.rad + Math.sin(a) * root.rad - 15
                    width: 30; height: 30
                    Rectangle { anchors.fill: parent; radius: 15; color: Theme.alpha(Theme.leatherDark, 0.92); border.width: 1.5
                                border.color: Theme.mix(Theme.gold, Theme.goldBright, root.ignite) }
                    Text { anchors.centerIn: parent; text: parent.modelData[0]; color: Theme.goldBright; font.family: "Noto Sans Symbols"; font.pixelSize: 15 }
                }
            }

            // the heptagram, turned so the chosen program is at the top
            Item {
                id: star
                anchors.fill: parent
                rotation: root.starTurn
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.alpha(Theme.mix(Theme.gold, Theme.goldBright, root.ignite), 0.85)
                        strokeWidth: 1.2 + root.ignite
                        fillColor: "transparent"
                        joinStyle: ShapePath.MiterJoin
                        PathSvg {
                            path: {
                                const pts = [];
                                for (let k = 0; k < 7; k++) {
                                    const a = (-90 + k * 360 / 7) * Math.PI / 180;
                                    pts.push([root.rad + Math.cos(a) * root.starR, root.rad + Math.sin(a) * root.starR]);
                                }
                                let d = "M " + pts[0].join(" ");
                                for (let i = 1; i <= 7; i++) d += " L " + pts[(i * 3) % 7].join(" ");
                                return d + " Z";
                            }
                        }
                    }
                }
                // the seven programs, one on each point
                Repeater {
                    model: 7
                    Item {
                        id: node
                        required property int index
                        readonly property var app: root.results[index] ?? null
                        readonly property bool picked: index === root.pick && !!app
                        readonly property real a: (-90 + index * 360 / 7) * Math.PI / 180
                        width: 44; height: 44
                        x: root.rad + Math.cos(a) * root.starR - 22
                        y: root.rad + Math.sin(a) * root.starR - 22
                        rotation: -root.starTurn - root.spin
                        scale: picked ? 1.18 : app ? 1 : 0.6
                        opacity: app ? 1 : 0.5
                        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
                        Rectangle {
                            anchors.fill: parent
                            radius: 22
                            color: Theme.alpha(Theme.leatherDark, 0.94)
                            border.width: node.picked ? 2 : 1
                            border.color: node.picked ? Theme.arcane : Theme.alpha(Theme.gold, 0.8)
                            layer.enabled: node.picked
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.arcane; shadowBlur: 0.8; shadowOpacity: 1
                                                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 20 }
                        }
                        IconImage {
                            visible: !!node.app
                            anchors.centerIn: parent
                            implicitSize: 26
                            source: root.iconFor(node.app)
                        }
                        Text {
                            visible: !node.app
                            anchors.centerIn: parent
                            text: Theme.allRunes[(node.index * 5) % Theme.allRunes.length]
                            color: Theme.alpha(Theme.gold, 0.6)
                            font.family: Theme.runic
                            font.pixelSize: 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !!node.app && !root.casting
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.pick === node.index) root.cast(); else root.pick = node.index; }
                        }
                    }
                }
            }

            // the letters, inscribed as runes round the inner ring
            Repeater {
                model: root.runes.length
                Text {
                    id: rn
                    required property int index
                    readonly property real a: (-90 + index * root.runeStep) * Math.PI / 180
                    x: root.rad + Math.cos(a) * (root.runeR - 20) - width / 2
                    y: root.rad + Math.sin(a) * (root.runeR - 20) - height / 2
                    rotation: -90 + index * root.runeStep + 90
                    text: root.runes[index] ?? ""
                    color: Theme.mix(Theme.arcane, "#ffffff", 0.25 + 0.5 * root.ignite)
                    font.family: Theme.runic
                    font.pixelSize: 24
                    property real born: 0
                    scale: 1 + (1 - born) * 1.4
                    opacity: born
                    NumberAnimation on born { from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.arcane; shadowBlur: 0.7; shadowOpacity: 1
                                                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 16; brightness: (1 - rn.born) * 0.5 }
                    Component.onCompleted: {
                        const p = rn.mapToItem(body, rn.width / 2, rn.height / 2);
                        sparks.burst(p.x, p.y, 14);
                    }
                }
            }

            // the centre: what you'd summon
            Item {
                anchors.centerIn: parent
                width: root.rad * 0.62
                height: width
                rotation: -root.spin
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    width: parent.width
                    IconImage {
                        visible: !!root.chosen
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: Math.round(root.rad * 0.22)
                        source: root.iconFor(root.chosen)
                    }
                    Text {
                        visible: !root.chosen
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.query.trim() ? "✦" : "ᛟ"
                        color: Theme.arcane
                        font.family: root.query.trim() ? Theme.symbols : Theme.runic
                        font.pixelSize: Math.round(root.rad * 0.18)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.chosen ? root.chosen.name : root.query.trim() ? root.query.trim() : "summon"
                        color: Theme.goldBright
                        font.family: Theme.uncial
                        font.pixelSize: 19
                    }
                    Body {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 24
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.chosen ? (root.chosen.genericName || root.chosen.comment || "") : root.query.trim() ? "cast it as a command" : ""
                        italic: true
                        color: Theme.alpha(Theme.fg, 0.75)
                        font.pixelSize: 13
                    }
                }
                MouseArea { anchors.fill: parent; enabled: !root.casting; cursorShape: Qt.PointingHandCursor; onClicked: root.cast() }
            }
        }

        // ---------------------------------------------------------------- the words below
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.cy + root.rad + 34
            spacing: 10
            opacity: root.shown * (1 - root.ignite)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.query || "speak the name of what you would summon"
                color: root.query ? Theme.fg : Theme.alpha(Theme.fg, 0.55)
                font.family: Theme.body
                font.italic: true
                font.pixelSize: root.query ? 24 : 18
                font.letterSpacing: root.query ? 2 : 0
            }
            Caps {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "enter casts   ·   tab turns the star   ·   esc dispels"
                color: Theme.alpha(Theme.gold, 0.7)
                font.pixelSize: 11
            }
        }

        // ---------------------------------------------------------------- the flash at the end
        Rectangle {
            visible: root.flash > 0 && root.flash < 1
            readonly property real d: 40 + root.flash * 260
            x: root.target.x - d / 2
            y: root.target.y - d / 2
            width: d; height: d; radius: d / 2
            color: "transparent"
            border.width: 3 * (1 - root.flash) + 1
            border.color: Theme.goldBright
            opacity: 1 - root.flash
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.arcane; shadowBlur: 1; shadowOpacity: 1
                                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 32 }
        }
        Rectangle {
            visible: root.flash > 0 && root.flash < 1
            readonly property real d: 24 + root.flash * 90
            x: root.target.x - d / 2
            y: root.target.y - d / 2
            width: d; height: d; radius: d / 2
            color: Theme.alpha(Theme.goldBright, 0.7 * (1 - root.flash))
        }
    }

    // the keyboard (hidden; what's typed is shown as runes and words)
    TextInput {
        id: keys
        width: 1; height: 1
        opacity: 0
        focus: true
        onTextEdited: root.query = text
        Keys.onPressed: e => {
            const n = Math.max(1, root.results.length);
            if (e.key === Qt.Key_Escape) { CircleState.open = false; e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.cast(); e.accepted = true; }
            else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_Down) { root.pick = (root.pick + 1) % n; e.accepted = true; }
            else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left || e.key === Qt.Key_Up) { root.pick = (root.pick - 1 + n) % n; e.accepted = true; }
        }
    }

    component Ring: ShapePath {
        property real r
        property real w: 1
        property color c: Theme.mix(Theme.gold, Theme.goldBright, root.ignite)
        strokeColor: c
        strokeWidth: w + root.ignite
        fillColor: "transparent"
        PathSvg { path: `M ${root.rad - r} ${root.rad} a ${r} ${r} 0 1 0 ${r * 2} 0 a ${r} ${r} 0 1 0 ${-r * 2} 0` }
    }
}
