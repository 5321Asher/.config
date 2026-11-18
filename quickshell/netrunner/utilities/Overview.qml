import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"

// SUBNET MAP サブネット: every workspace as a node with live previews of its windows. Click a window
// to jump to it, click a node to go there, drag a window onto another node to move it, 1-9 to go,
// Esc closes. Opens from the screen's top-left click corner (utilities/Corner.qml), right-click on
// the workspace numbers, SUPER + O or qs ipc call overview toggle.
// Opening runs a network scan: a ring blasts out from where it was opened, lighting a hex grid, and
// the nodes materialise in the order the ring reaches them (outline drawn, popping in oversized,
// glitching into focus, the number decoding) while the links between them draw themselves and data
// packets start running. Hover a node: it lifts, bursts red / cyan, a light races round its edge, its
// corner brackets spring out, a scan bar sweeps its preview and its links light up. Closing: the nodes
// implode one after another and the ring sucks back into where it came from; going to a workspace
// dives into its node instead.
PanelWindow {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    property var dragging: null
    property point dragPos
    property int hoverWs: -1
    readonly property int count: Math.max(5, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))

    function close() { if (OverviewState.open) { diveWs = -1; outro.play(); OverviewState.open = false; } }
    function addr(t) { return t.address.startsWith("0x") ? t.address : "0x" + t.address; }
    function focusWindow(t, ws) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`); dive(ws); }
    function goTo(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws} })`); dive(ws); }
    // going somewhere: that node zooms up to fill the screen while the rest implode
    property int diveWs: -1
    function dive(ws) { if (!OverviewState.open) return; diveWs = ws; outro.play(); OverviewState.open = false; }
    function moveWindow(t, ws) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${addr(t)}", follow = false })`);
        refreshSoon.restart();
    }
    function appIcon(cls) { const e = DesktopEntries.heuristicLookup(cls); return Quickshell.iconPath(e?.icon || cls || "application-x-executable", "application-x-executable"); }
    function monitorSize(mon) {
        const o = mon?.lastIpcObject ?? {};
        const w = o.width ?? mon?.width ?? 1920, h = o.height ?? mon?.height ?? 1080, s = o.scale ?? 1;
        return (o.transform ?? 0) % 2 === 1 ? { w: h / s, h: w / s, x: o.x ?? 0, y: o.y ?? 0 } : { w: w / s, h: h / s, x: o.x ?? 0, y: o.y ?? 0 };
    }

    // Follows the focused monitor only while hidden: moving a shown window rebuilds its surface
    Binding on screen {
        when: !root.visible
        value: root.focusedScreen
        restoreMode: Binding.RestoreNone
    }
    visible: OverviewState.open || outro.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "netrunner-overview"
    WlrLayershell.keyboardFocus: OverviewState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: OverviewState.open ? null : noInput
    Region { id: noInput }

    // ---------------------------------------------------------------- the clocks
    Driver { id: intro; until: 1500 }
    Driver { id: outro; until: 620 }
    property real time: 0
    FrameAnimation { running: root.visible; onTriggered: root.time += Math.min(frameTime, 1 / 30) }
    Connections {
        target: OverviewState
        function onOpenChanged() {
            if (OverviewState.open) {
                outro.stop();
                root.diveWs = -1;
                Hyprland.refreshMonitors();
                Hyprland.refreshToplevels();
                scope.forceActiveFocus();
                decode.replay();
                intro.play();
            } else if (!outro.running) outro.play();      // closed from outside
            root.dragging = null;
        }
    }
    Connections {
        target: outro
        function onRunningChanged() { if (!outro.running && !OverviewState.open) OverviewState.origin = Qt.point(-1, -1); }
    }
    Timer { id: refreshSoon; interval: 150; onTriggered: Hyprland.refreshToplevels() }

    // where the scan starts: the clicked corner, else the middle
    readonly property point origin: OverviewState.origin.x >= 0 ? OverviewState.origin : Qt.point(width / 2, height / 2)
    readonly property real reach: Math.hypot(Math.max(origin.x, width - origin.x), Math.max(origin.y, height - origin.y))
    readonly property real ringR: intro.running ? reach * Theme.out3(Theme.seg(intro.ms, 0, 700)) * 1.05
        : outro.running ? reach * (1 - Theme.inOut(Theme.seg(outro.ms, 120, 620))) * 1.05 : OverviewState.open ? reach * 1.05 : 0
    // a node's start in the intro: when the ring reaches it
    function arrival(p) { return 700 * Math.acos(1 - Math.min(1, Math.hypot(p.x - origin.x, p.y - origin.y) / (reach * 1.05))) / (Math.PI / 2) * 0.9; }
    // 0..1 how far a node has come in (intro) / gone (outro: nearest the origin last, so they're pulled home)
    function nodeIn(p) {
        if (intro.running) return Theme.seg(intro.ms, arrival(p), arrival(p) + 560);
        if (outro.running) return 1 - Theme.seg(outro.ms, 300 * (1 - Math.min(1, Math.hypot(p.x - origin.x, p.y - origin.y) / reach)), 300 * (1 - Math.min(1, Math.hypot(p.x - origin.x, p.y - origin.y) / reach)) + 280);
        return OverviewState.open ? 1 : 0;
    }
    function outBack(x) { const c1 = 2.2, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); }

    // ---------------------------------------------------------------- the scan
    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/scan.frag.qsb")
        property vector2d size: Qt.vector2d(width, height)
        property vector2d origin: Qt.vector2d(root.origin.x, root.origin.y)
        property real radius: root.ringR
        property real dim: 0.82
        property real time: root.time
        property color ring: Theme.red
        property color grid: Theme.cyan
        property color base: Theme.bgDark
    }
    Text {           // jacking in
        anchors.centerIn: parent
        visible: intro.running && intro.ms < 600
        opacity: Theme.seg(intro.ms, 40, 120) * (1 - Theme.seg(intro.ms, 420, 600)) * (Math.random() < 0.2 ? 0.3 : 1)
        text: "SCANNING SUBNET"
        color: Theme.red
        font.family: Theme.display; font.pixelSize: 64; font.weight: Font.Bold; font.letterSpacing: 10
        style: Text.Outline; styleColor: Theme.bgDark
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onPressed: e => { const n = e.key - Qt.Key_0; if (n >= 1 && n <= 9) { root.goTo(n); e.accepted = true; } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        // the links between the nodes, drawn as the nodes arrive, data running along them
        Item {
            id: links
            anchors.fill: parent
            readonly property var nodes: grid.children.filter(c => c.wsId !== undefined)
            Repeater {
                model: Math.max(0, root.count - 1) + Math.max(0, root.count - grid.cols)
                Item {
                    id: link
                    required property int index
                    readonly property bool across: index < root.count - 1
                    readonly property int a: across ? index : index - (root.count - 1)
                    readonly property int b: across ? a + 1 : a + grid.cols
                    readonly property var na: links.nodes[a] ?? null
                    readonly property var nb: links.nodes[b] ?? null
                    readonly property point pa: na ? na.center : Qt.point(0, 0)
                    readonly property point pb: nb ? nb.center : Qt.point(0, 0)
                    readonly property real drawn: Math.min(na ? root.nodeIn(pa) : 0, nb ? root.nodeIn(pb) : 0)
                    readonly property bool lit: root.hoverWs === a + 1 || root.hoverWs === b + 1
                    visible: na !== null && nb !== null && !(across && Math.floor(a / grid.cols) !== Math.floor(b / grid.cols)) && drawn > 0
                    Shape {
                        width: root.width; height: root.height
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: link.lit ? Theme.red : Theme.alpha(Theme.cyan, 0.45)
                            strokeWidth: link.lit ? 2.5 : 1.2
                            fillColor: "transparent"
                            dashPattern: [4, 3]
                            strokeStyle: link.lit ? ShapePath.SolidLine : ShapePath.DashLine
                            startX: link.pa.x; startY: link.pa.y
                            PathLine { x: link.pa.x + (link.pb.x - link.pa.x) * link.drawn; y: link.pa.y + (link.pb.y - link.pa.y) * link.drawn }
                        }
                    }
                    Repeater {        // data packets
                        model: link.lit ? 4 : 2
                        Rectangle {
                            required property int index
                            readonly property real t: ((root.time * (link.lit ? 0.9 : 0.35) + index / (link.lit ? 4 : 2) + link.index * 0.17) % 1)
                            visible: link.drawn >= 1
                            x: link.pa.x + (link.pb.x - link.pa.x) * t - width / 2
                            y: link.pa.y + (link.pb.y - link.pa.y) * t - height / 2
                            width: link.lit ? 8 : 5; height: width
                            rotation: 45
                            color: link.lit ? Theme.bright : Theme.cyan
                        }
                    }
                }
            }
        }

        Column {
            id: layoutCol
            anchors.centerIn: parent
            spacing: 26

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                opacity: intro.running ? Theme.seg(intro.ms, 500, 800) : outro.running ? 1 - Theme.seg(outro.ms, 0, 200) : 1
                Tag { anchors.verticalCenter: parent.verticalCenter; text: "NET"; height: 24 }
                Scramble { id: decode; anchors.verticalCenter: parent.verticalCenter; target: "SUBNET MAP"; duration: 500; color: Theme.bright
                           font.family: Theme.display; font.pixelSize: 30; font.weight: Font.Bold }
                Jp { anchors.verticalCenter: parent.verticalCenter; text: "サブネット"; font.pixelSize: 16 }
                Label { anchors.verticalCenter: parent.verticalCenter
                        text: "//  " + Hyprland.toplevels.values.length + " NODES ACROSS " + root.count + " SUBNETS" }
            }

            Grid {
                id: grid
                anchors.horizontalCenter: parent.horizontalCenter
                // the column count that makes the tiles biggest on this screen: a row on a landscape
                // screen, a stack on a portrait one. Each tile keeps its own monitor's shape inside
                // a cell of the focused monitor's shape.
                readonly property var mon: root.monitorSize(Hyprland.focusedMonitor)
                readonly property var fit: {
                    const W = root.width - 160, H = root.height - 260, gap = 34, label = 30, a = mon.w / mon.h;
                    let best = { cols: 1, w: 0 };
                    for (let c = 1; c <= root.count; c++) {
                        const r = Math.ceil(root.count / c);
                        const w = Math.min((W - (c - 1) * gap) / c, ((H - (r - 1) * gap) / r - label) * a, 400);
                        if (w > best.w) best = { cols: c, w: w };
                    }
                    return best;
                }
                readonly property int cols: fit.cols
                readonly property real cellW: fit.w
                readonly property real cellH: fit.w * mon.h / mon.w
                columns: cols
                spacing: 34

                Repeater {
                    model: root.count
                    Column {
                        id: col
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                        readonly property var mon: root.monitorSize(ws?.monitor ?? Hyprland.focusedMonitor)
                        readonly property real k: Math.min(grid.cellW / mon.w, grid.cellH / mon.h)
                        readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId)
                        readonly property bool current: Hyprland.focusedWorkspace?.id === wsId
                        readonly property bool hot: root.hoverWs === wsId
                        // where the node's middle is on the screen (the links and the scan use it)
                        readonly property point center: { grid.x; grid.y; layoutCol.x; layoutCol.y; col.x; col.y; return tile.mapToItem(scope, tile.width / 2, tile.height / 2); }
                        readonly property real k_in: root.nodeIn(center)
                        readonly property bool diving: outro.running && root.diveWs === wsId
                        function hits(p) { const q = tile.mapFromItem(null, p.x, p.y); return q.x >= 0 && q.y >= 0 && q.x < tile.width && q.y < tile.height; }
                        spacing: 6
                        z: hot || diving ? 5 : 1

                        // hovering: an animation of its own
                        Driver { id: hoverIn; until: 450 }
                        onHotChanged: if (hot) hoverIn.play()
                        readonly property real lift: hot ? root.outBack(Theme.seg(hoverIn.ms, 0, 320)) : 0

                        Item {
                            id: tile
                            width: col.mon.w * col.k
                            height: col.mon.h * col.k
                            // arriving: oversized and settling; leaving: imploding; diving: filling the screen
                            readonly property real arriveScale: col.k_in <= 0 ? 0.01 : intro.running ? 0.4 + 0.6 * root.outBack(Theme.seg(col.k_in, 0.15, 1)) : 1
                            readonly property real diveScale: col.diving ? 1 + Theme.inOut(Theme.seg(outro.ms, 0, 520)) * Math.max(root.width / width, root.height / height) * 1.1 : 1
                            scale: (outro.running && !col.diving ? Math.max(0.01, Theme.out3(col.k_in)) : arriveScale) * (1 + 0.08 * col.lift) * diveScale
                            opacity: col.diving ? 1 - Theme.seg(outro.ms, 380, 600) : intro.running ? Theme.seg(col.k_in, 0.1, 0.4) : outro.running ? Math.min(1, col.k_in * 1.5) : 1
                            transformOrigin: Item.Center
                            readonly property real glitch: Math.max(intro.running ? 1 - Theme.seg(col.k_in, 0.3, 1) : 0,
                                                                     outro.running && !col.diving ? 1 - col.k_in : 0,
                                                                     col.hot ? 0.55 * (1 - Theme.seg(hoverIn.ms, 0, 300)) : 0)
                            layer.enabled: glitch > 0.002
                            layer.effect: ShaderEffect {
                                fragmentShader: Qt.resolvedUrl("../shaders/glitch.frag.qsb")
                                property vector2d size: Qt.vector2d(tile.width, tile.height)
                                property real amount: tile.glitch
                                property real time: root.time
                                property real seed: col.index * 0.13
                                property color red: Theme.red
                                property color cyan: Theme.cyan
                            }

                            Item {
                                anchors.fill: parent
                                clip: true
                                Chamfer { anchors.fill: parent; cut: 12; corners: "tr bl"; fill: Theme.alpha(Theme.bg, 0.92)
                                          stroke: col.hot ? Theme.red : col.current ? Theme.cyan : Theme.line
                                          strokeWidth: col.current || col.hot ? 2 : 1 }
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onEntered: if (!root.dragging) root.hoverWs = col.wsId
                                    onExited: if (!root.dragging && root.hoverWs === col.wsId) root.hoverWs = -1
                                    onClicked: root.goTo(col.wsId)
                                }
                                Label { anchors.centerIn: parent; visible: col.windows.length === 0; text: "// EMPTY SUBNET" }
                                Repeater {
                                    model: col.windows
                                    Item {
                                        id: win
                                        required property var modelData
                                        readonly property var ipc: modelData.lastIpcObject ?? {}
                                        x: ((ipc.at?.[0] ?? 0) - col.mon.x) * col.k
                                        y: ((ipc.at?.[1] ?? 0) - col.mon.y) * col.k
                                        width: Math.max(28, (ipc.size?.[0] ?? 200) * col.k)
                                        height: Math.max(22, (ipc.size?.[1] ?? 150) * col.k)
                                        z: ipc.floating ? 2 : 1
                                        opacity: root.dragging === modelData ? 0.3 : 1
                                        Rectangle { anchors.fill: parent; color: Theme.surface; border.width: 1
                                                    border.color: winMouse.containsMouse ? Theme.red : Theme.alpha(Theme.cyan, 0.4) }
                                        ScreencopyView { id: preview; anchors.fill: parent; anchors.margins: 1
                                                         captureSource: root.visible ? win.modelData.wayland : null; live: true }
                                        IconImage { anchors.centerIn: parent; visible: !preview.hasContent; implicitSize: Math.min(32, parent.height - 6)
                                                    source: root.appIcon(win.ipc.class ?? "") }
                                        MouseArea {
                                            id: winMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            property point pressAt
                                            onEntered: if (!root.dragging) root.hoverWs = col.wsId
                                            onPressed: e => pressAt = Qt.point(e.x, e.y)
                                            onPositionChanged: e => {
                                                if (!pressed) return;
                                                if (!root.dragging && Math.hypot(e.x - pressAt.x, e.y - pressAt.y) > 6) root.dragging = win.modelData;
                                                if (root.dragging) {
                                                    root.dragPos = mapToItem(null, e.x, e.y);
                                                    root.hoverWs = -1;
                                                    for (const c of grid.children) if (c.hits && c.hits(root.dragPos)) root.hoverWs = c.wsId;
                                                }
                                            }
                                            onReleased: {
                                                if (root.dragging) {
                                                    if (root.hoverWs > 0 && root.hoverWs !== col.wsId) root.moveWindow(win.modelData, root.hoverWs);
                                                    root.dragging = null;
                                                    root.hoverWs = -1;
                                                } else root.focusWindow(win.modelData, col.wsId);
                                            }
                                        }
                                    }
                                }
                                // the hover scan sweeping down the preview
                                Rectangle {
                                    visible: col.hot
                                    width: parent.width; height: 24
                                    y: ((root.time * 0.9) % 1) * (parent.height + 24) - 24
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.9; color: Theme.alpha(Theme.cyan, 0.25) }
                                        GradientStop { position: 1.0; color: Theme.alpha(Theme.bright, 0.8) }
                                    }
                                }
                            }
                            // the outline drawing itself as it arrives
                            Item {
                                anchors.fill: parent
                                visible: intro.running && col.k_in < 1
                                readonly property real t: Theme.seg(col.k_in, 0, 0.45)
                                Rectangle { width: parent.width * Math.min(1, parent.t * 4); height: 2; color: Theme.bright }
                                Rectangle { x: parent.width - 2; width: 2; height: parent.height * Theme.seg(parent.t, 0.25, 0.5); color: Theme.bright }
                                Rectangle { x: parent.width * (1 - Theme.seg(parent.t, 0.5, 0.75)); y: parent.height - 2; width: parent.width * Theme.seg(parent.t, 0.5, 0.75); height: 2; color: Theme.bright }
                                Rectangle { height: parent.height * Theme.seg(parent.t, 0.75, 1); y: parent.height - height; width: 2; color: Theme.bright }
                            }
                            // hovered: a light racing round the edge
                            Rectangle {
                                visible: col.hot
                                readonly property real p: ((root.time * 0.7) % 1) * 2 * (tile.width + tile.height)
                                readonly property real w2: tile.width
                                readonly property real h2: tile.height
                                width: 26; height: 4
                                color: Theme.bright
                                x: p < w2 ? p - 13 : p < w2 + h2 ? w2 - 2 : p < 2 * w2 + h2 ? w2 - (p - w2 - h2) - 13 : -2
                                y: p < w2 ? -2 : p < w2 + h2 ? p - w2 - 2 : p < 2 * w2 + h2 ? h2 - 2 : h2 - (p - 2 * w2 - h2) - 2
                                rotation: p < w2 || (p >= w2 + h2 && p < 2 * w2 + h2) ? 0 : 90
                            }
                        }
                        // hovered: brackets springing out of the corners
                        Item {
                            width: tile.width; height: 0
                            Repeater {
                                model: 4
                                Item {
                                    required property int index
                                    readonly property real off: 8 + 10 * col.lift
                                    visible: col.hot
                                    x: index % 2 ? tile.width + off - 14 : -off
                                    y: (index > 1 ? tile.height + off - 14 : -off)
                                    width: 14; height: 14
                                    Rectangle { x: index % 2 ? 12 : 0; width: 2; height: 14; color: Theme.red }
                                    Rectangle { y: index > 1 ? 12 : 0; width: 14; height: 2; color: Theme.red }
                                }
                            }
                        }
                        Row {
                            spacing: 8
                            opacity: tile.opacity
                            Text { text: String(col.wsId).padStart(2, "0"); color: col.hot ? Theme.red : col.current ? Theme.cyan : Theme.fg
                                   font.family: Theme.display; font.pixelSize: 16 + 8 * col.lift; font.weight: Font.Bold }
                            Tag { anchors.verticalCenter: parent.verticalCenter; visible: col.hot; text: "JACK IN"; height: 18; pixelSize: 10 }
                            Label { anchors.verticalCenter: parent.verticalCenter; text: col.windows.length ? col.windows.length + " NODE" + (col.windows.length === 1 ? "" : "S") : "" }
                        }
                    }
                }
            }
        }
    }

    // the window being dragged
    IconImage {
        visible: root.dragging !== null
        x: root.dragPos.x - 16
        y: root.dragPos.y - 16
        implicitSize: 32
        source: root.appIcon(root.dragging?.lastIpcObject?.class ?? "")
    }

    Binding {
        target: OverviewState; property: "status"
        value: `open=${OverviewState.open} visible=${root.visible} hover=${root.hoverWs} origin=${Math.round(root.origin.x)},${Math.round(root.origin.y)} nodes=${root.count}`
    }
}
