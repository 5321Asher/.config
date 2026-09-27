import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import "../theme"

// 7 · Star-chart launcher. A graduated brass dial; every app is a star on one of three rings,
// alphabetical clockwise from the top. Type to search: matching stars light up and are joined,
// best first, by phosphor constellation lines, and a telescope pointer swings to the best match.
// Enter launches it, ↑ ↓ / Tab step through the matches, Esc closes. Click a star to launch it.
// Opened with: qs ipc call starchart toggle
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: StarChartState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-starchart"
    WlrLayershell.keyboardFocus: StarChartState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // 0 closed .. 1 open
    property real shown: StarChartState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

    // ---------------------------------------------------------------- apps and search
    readonly property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    property string query: ""
    property int pick: 0            // index into matches (or into apps while the query is empty)

    // How well an app matches, plus a boost for the ones you launch often
    function score(a, q) {
        const s = match(a, q);
        return s > 0 ? s + Math.min(Theme.launchBoost, 9 * Math.log2(1 + (launches[a.id] ?? 0))) : 0;
    }
    function match(a, q) {
        const name = a.name.toLowerCase();
        if (name.startsWith(q)) return 100 - name.length * 0.1;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (q.length < 2) return 0;          // one letter: only names starting with it, or a word in them
        if (name.includes(q)) return 60;
        if (q.length < 3) return 0;          // descriptions and keywords from three letters on
        const more = [a.genericName ?? "", (a.keywords ?? []).join(" "), a.comment ?? "", a.id ?? ""]
            .join(" ").toLowerCase();
        if (more.includes(q)) return 40;
        return 0;
    }

    // Launch counts per desktop id, kept in Quickshell's state folder
    property var launches: ({})
    FileView {
        id: usage
        path: Quickshell.statePath("starchart-launches.json")
        printErrors: false
        onLoaded: { try { root.launches = JSON.parse(text()); } catch (e) {} }
    }
    // Indices into `apps`, best first
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        if (q === "") return [];
        return apps.map((a, i) => ({ i: i, s: score(a, q) }))
            .filter(m => m.s > 0)
            .sort((x, y) => y.s - x.s || apps[x.i].name.localeCompare(apps[y.i].name))
            .map(m => m.i);
    }
    readonly property int target: matches.length > 0 ? matches[Math.min(pick, matches.length - 1)]
                                : query === "" && pick >= 0 && pick < apps.length && browsing ? pick : -1
    property bool browsing: false   // arrows used with an empty query
    onQueryChanged: { pick = 0; browsing = false; }

    function launch(i) {
        const a = apps[i];
        if (!a) return;
        const counts = Object.assign({}, launches);
        counts[a.id] = (counts[a.id] ?? 0) + 1;
        launches = counts;
        usage.setText(JSON.stringify(launches));
        a.execute();
        StarChartState.open = false;
    }
    function step(d) {
        if (matches.length > 0) pick = (pick + d + matches.length) % matches.length;
        else if (apps.length > 0) { pick = browsing ? (pick + d + apps.length) % apps.length : 0; browsing = true; }
    }

    Connections {
        target: StarChartState
        function onOpenChanged() {
            if (StarChartState.open) { root.query = ""; root.pick = 0; root.browsing = false; input.forceActiveFocus(); }
        }
    }

    // ---------------------------------------------------------------- geometry
    readonly property real dialR: Math.min(Theme.chartRadius, Math.min(width, height) * 0.42)
    readonly property real ccx: width / 2
    readonly property real ccy: height / 2
    readonly property var rings: [dialR * 0.52, dialR * 0.7, dialR * 0.88]
    function starPos(i) {
        const n = apps.length;
        const a = -Math.PI / 2 + (i + 0.5) / n * 2 * Math.PI;
        const r = rings[i % 3];
        return { x: ccx + r * Math.cos(a), y: ccy + r * Math.sin(a), a: a, r: r };
    }

    // The whole chart swings in a little as it opens
    readonly property real swing: (1 - shown) * -0.35

    // ---------------------------------------------------------------- sky
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bgDark, Theme.chartDim * root.shown)
    }
    MouseArea {
        anchors.fill: parent
        onClicked: StarChartState.open = false
    }

    Item {
        id: chart
        anchors.fill: parent
        opacity: root.shown
        scale: 0.94 + 0.06 * root.shown
        transformOrigin: Item.Center

        // The dial: rings, graduations, hour numerals, crosshair
        Item {
            id: dialLayer
            anchors.fill: parent
            rotation: root.swing * 180 / Math.PI

            Canvas {
                id: dial
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = root.ccx, cy = root.ccy, R = root.dialR;

                    // Face
                    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, R * 1.08);
                    g.addColorStop(0, Theme.alpha(Theme.surface, 0.92));
                    g.addColorStop(0.7, Theme.alpha(Theme.bg, 0.9));
                    g.addColorStop(1, Theme.alpha(Theme.bgDark, 0.94));
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(cx, cy, R * 1.08, 0, 2 * Math.PI);
                    ctx.fill();

                    // Outer bezel: two brass rings with degree graduations between them
                    ctx.strokeStyle = Theme.brass;
                    ctx.lineWidth = 1.6;
                    ctx.beginPath(); ctx.arc(cx, cy, R * 1.08, 0, 2 * Math.PI); ctx.stroke();
                    ctx.lineWidth = 0.8;
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.6);
                    ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.stroke();
                    for (let d = 0; d < 360; d += 2) {
                        const a = d * Math.PI / 180, major = d % 10 === 0, big = d % 30 === 0;
                        const r2 = R + (big ? R * 0.05 : major ? R * 0.035 : R * 0.018);
                        ctx.strokeStyle = Theme.alpha(Theme.brass, big ? 0.95 : major ? 0.7 : 0.4);
                        ctx.lineWidth = big ? 1.4 : 0.8;
                        ctx.beginPath();
                        ctx.moveTo(cx + R * Math.cos(a), cy + R * Math.sin(a));
                        ctx.lineTo(cx + r2 * Math.cos(a), cy + r2 * Math.sin(a));
                        ctx.stroke();
                    }
                    // Hour numerals round the outside
                    ctx.fillStyle = Theme.alpha(Theme.brass, 0.8);
                    ctx.font = `600 ${Theme.labelSize}px "${Theme.fontLabel}"`;
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    for (let h = 0; h < 24; h += 2) {
                        const a = -Math.PI / 2 + h / 24 * 2 * Math.PI, r = R * 1.15;
                        ctx.fillText(`${String(h).padStart(2, "0")}h`, cx + r * Math.cos(a), cy + r * Math.sin(a));
                    }

                    // Star rings, dashed, and the crosshair
                    ctx.setLineDash([2, 6]);
                    ctx.lineWidth = 0.7;
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.25);
                    for (const r of root.rings) { ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.stroke(); }
                    ctx.setLineDash([]);
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.14);
                    for (let k = 0; k < 12; k++) {
                        const a = k * Math.PI / 6;
                        ctx.beginPath();
                        ctx.moveTo(cx + R * 0.33 * Math.cos(a), cy + R * 0.33 * Math.sin(a));
                        ctx.lineTo(cx + R * Math.cos(a), cy + R * Math.sin(a));
                        ctx.stroke();
                    }
                    // An ecliptic: a tilted ellipse, very faint
                    ctx.save();
                    ctx.translate(cx, cy);
                    ctx.rotate(-0.41);
                    ctx.scale(1, 0.38);
                    ctx.strokeStyle = Theme.alpha(Theme.phosphor, 0.12);
                    ctx.lineWidth = 1.5;
                    ctx.beginPath(); ctx.arc(0, 0, R * 0.95, 0, 2 * Math.PI); ctx.stroke();
                    ctx.restore();

                    // Background dust: faint fixed stars
                    let seed = 7;
                    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
                    for (let k = 0; k < 260; k++) {
                        const a = rnd() * 2 * Math.PI, r = Math.sqrt(rnd()) * R;
                        ctx.fillStyle = Theme.alpha(Theme.starlight, 0.1 + rnd() * 0.3);
                        ctx.beginPath();
                        ctx.arc(cx + r * Math.cos(a), cy + r * Math.sin(a), 0.4 + rnd() * 0.7, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: Theme
                    function onPaletteChanged() { dial.requestPaint(); }
                }
            }
        }

        // Constellation lines between the matches, best first, and the telescope pointer
        Item {
            id: linesLayer
            anchors.fill: parent

            Canvas {
                id: lines
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const m = root.matches.slice(0, Theme.constellationMax);
                    if (m.length > 1) {
                        ctx.strokeStyle = Theme.alpha(Theme.phosphor, 0.55);
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        m.forEach((i, k) => {
                            const p = root.starPos(i);
                            if (k === 0) ctx.moveTo(p.x, p.y); else ctx.lineTo(p.x, p.y);
                        });
                        ctx.stroke();
                    }
                    // Pointer: from the hub's edge to the target, with a reticle round it
                    if (root.target >= 0) {
                        const p = root.starPos(root.target);
                        const hub = root.dialR * 0.33;
                        ctx.strokeStyle = Theme.alpha(Theme.brass, 0.85);
                        ctx.lineWidth = 1.2;
                        ctx.beginPath();
                        ctx.moveTo(root.ccx + hub * Math.cos(p.a), root.ccy + hub * Math.sin(p.a));
                        ctx.lineTo(root.ccx + (p.r - 14) * Math.cos(p.a), root.ccy + (p.r - 14) * Math.sin(p.a));
                        ctx.stroke();
                        ctx.strokeStyle = Theme.brassBright;
                        ctx.lineWidth = 1.2;
                        ctx.beginPath(); ctx.arc(p.x, p.y, 11, 0, 2 * Math.PI); ctx.stroke();
                        for (let k = 0; k < 4; k++) {
                            const a = k * Math.PI / 2;
                            ctx.beginPath();
                            ctx.moveTo(p.x + 14 * Math.cos(a), p.y + 14 * Math.sin(a));
                            ctx.lineTo(p.x + 19 * Math.cos(a), p.y + 19 * Math.sin(a));
                            ctx.stroke();
                        }
                    }
                }
                Connections {
                    target: root
                    function onMatchesChanged() { lines.requestPaint(); }
                    function onTargetChanged() { lines.requestPaint(); }
                    function onWidthChanged() { lines.requestPaint(); }
                }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.phosphor
                shadowBlur: 0.5
                shadowOpacity: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 16
            }
        }

        // The stars: one per app, labelled
        Repeater {
            model: root.apps

            Item {
                id: star
                required property var modelData
                required property int index
                readonly property var p: root.starPos(index)
                readonly property int rank: root.matches.indexOf(index)
                readonly property bool lit: rank >= 0
                readonly property bool isTarget: root.target === index
                readonly property bool dimmed: root.query !== "" && !lit
                readonly property bool rightSide: Math.cos(p.a) >= -0.05

                x: p.x
                y: p.y

                // the star itself
                Rectangle {
                    id: dot
                    property real d: star.isTarget ? 8 : star.lit ? 6 : 3.5
                    x: -d / 2
                    y: -d / 2
                    width: d
                    height: d
                    radius: d / 2
                    color: star.isTarget ? Theme.brassBright : star.lit ? Theme.phosphor : Theme.starlight
                    opacity: star.dimmed ? 0.25 : 1
                    Behavior on d { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    layer.enabled: star.lit || star.isTarget
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: star.isTarget ? Theme.brass : Theme.phosphor
                        shadowBlur: 0.6
                        shadowOpacity: 1
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                        blurMax: 12
                    }
                }
                Text {
                    x: star.rightSide ? 9 : -width - 9
                    y: -height / 2
                    text: star.modelData.name
                    color: star.isTarget ? Theme.brassBright : star.lit ? Theme.phosphor : Theme.fg
                    opacity: star.dimmed ? 0.18 : star.lit || star.isTarget ? 1 : 0.55
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall + (star.lit ? 1 : 0)
                    font.weight: star.isTarget ? Font.DemiBold : Font.Normal
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                }
                MouseArea {
                    x: -12; y: -12; width: 24 + 110; height: 24
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launch(star.index)
                }
            }
        }

        // ---------------------------------------------------------------- the hub
        Item {
            id: hub
            readonly property real r: root.dialR * 0.33
            x: root.ccx - r
            y: root.ccy - r
            width: r * 2
            height: r * 2

            MouseArea { anchors.fill: parent }   // clicks on the hub don't close the chart
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.alpha(Theme.bgDark, 0.95)
                border.width: 1.5
                border.color: Theme.brass
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: width / 2
                color: "transparent"
                border.width: 0.8
                border.color: Theme.alpha(Theme.brass, 0.35)
            }

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.78
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "star chart"
                    color: Theme.brass
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing * 2
                    font.weight: Font.DemiBold
                }

                // What you've typed, with a phosphor cursor
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideLeft
                    text: (root.query === "" ? "" : root.query) + (cursorBlink.on ? "▌" : " ")
                    color: Theme.phosphor
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize + 5
                    Timer {
                        id: cursorBlink
                        property bool on: true
                        interval: 500; repeat: true; running: StarChartState.open
                        onTriggered: on = !on
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.brass, 0.3) }

                // The target: icon, name, what it is
                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property string ic: root.target >= 0 ? (root.apps[root.target]?.icon ?? "") : ""
                    active: ic.startsWith("/") || (ic !== "" && Quickshell.hasThemeIcon(ic))
                    visible: active
                    sourceComponent: IconImage {
                        implicitSize: 36
                        source: parent.ic.startsWith("/") ? parent.ic : Quickshell.iconPath(parent.ic)
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.target >= 0 ? root.apps[root.target].name
                        : root.query !== "" ? "no signal" : `${root.apps.length} bodies charted`
                    color: root.target >= 0 ? Theme.brassBright : Theme.dim
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge + 4
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: root.target >= 0 ? (root.apps[root.target].genericName || root.apps[root.target].comment || "")
                        : root.query === "" ? "type to search · ↑↓ to browse" : ""
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.matches.length > 1
                    text: `${Math.min(root.pick, root.matches.length - 1) + 1} / ${root.matches.length}`
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
        }
    }

    // ---------------------------------------------------------------- keyboard
    TextInput {
        id: input
        opacity: 0
        width: 1
        height: 1
        focus: StarChartState.open
        text: root.query
        onTextEdited: root.query = text
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { StarChartState.open = false; event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.target >= 0) root.launch(root.target);
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                root.step(1); event.accepted = true;
            }
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) { root.step(-1); event.accepted = true; }
        }
    }
}
