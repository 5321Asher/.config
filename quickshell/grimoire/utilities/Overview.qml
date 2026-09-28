import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../bar"

// The whole book: every chapter (workspace) laid open on the desk as a page, with live pictures of
// its windows on it; the open chapter carries the ribbon. Click a window to go to it, a page to turn
// to that chapter, drag a window onto another page to move it there; 1-9 turn, Esc closes.
//   qs ipc call overview toggle (or right-click the chapters, or click the ribbon)
PanelWindow {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    property var dragging: null
    property point dragPos
    property int hoverWs: -1
    readonly property int count: Math.max(5, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))

    function close() { OverviewState.open = false; }
    function addr(t) { return t.address.startsWith("0x") ? t.address : "0x" + t.address; }
    function focusWindow(t) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`); close(); }
    function goTo(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws} })`); close(); }
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

    screen: focusedScreen
    visible: OverviewState.open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "grimoire-overview"
    WlrLayershell.keyboardFocus: OverviewState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: OverviewState
        function onOpenChanged() {
            if (OverviewState.open) { Hyprland.refreshMonitors(); Hyprland.refreshToplevels(); scope.forceActiveFocus(); }
            root.dragging = null;
        }
    }
    Timer { id: refreshSoon; interval: 150; onTriggered: Hyprland.refreshToplevels() }

    Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.veil, 0.82) }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onPressed: e => { const n = e.key - Qt.Key_0; if (n >= 1 && n <= 9) { root.goTo(n); e.accepted = true; } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Column {
            anchors.centerIn: parent
            spacing: 26

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "The Whole Book"
                    color: Theme.goldBright
                    font.family: Theme.blackletter
                    font.pixelSize: 46
                }
                Body {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.count + " chapters, " + Hyprland.toplevels.values.length + (Hyprland.toplevels.values.length === 1 ? " page" : " pages") + " within"
                    italic: true
                    color: Theme.alpha(Theme.fg, 0.75)
                }
                GoldRule { anchors.horizontalCenter: parent.horizontalCenter; width: 320; ornament: "❦" }
            }

            Grid {
                id: grid
                anchors.horizontalCenter: parent.horizontalCenter
                // the column count that makes the tiles biggest on this screen: a row on a landscape
                // screen, a stack on a portrait one. Each tile keeps its own monitor's shape inside
                // a cell of the focused monitor's shape.
                readonly property var mon: root.monitorSize(Hyprland.focusedMonitor)
                readonly property var fit: {
                    const W = root.width - 120, H = root.height - 220, gap = 18, label = 30, a = mon.w / mon.h;
                    let best = { cols: 1, w: 0 };
                    for (let c = 1; c <= root.count; c++) {
                        const r = Math.ceil(root.count / c);
                        const w = Math.min((W - (c - 1) * gap) / c, ((H - (r - 1) * gap) / r - label) * a, 420);
                        if (w > best.w) best = { cols: c, w: w };
                    }
                    return best;
                }
                readonly property int cols: fit.cols
                readonly property real cellW: fit.w
                readonly property real cellH: fit.w * mon.h / mon.w
                columns: cols
                spacing: 18

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
                        function hits(p) { const q = tile.mapFromItem(null, p.x, p.y); return q.x >= 0 && q.y >= 0 && q.x < tile.width && q.y < tile.height; }
                        spacing: 6

                        Item {
                            id: tile
                            width: col.mon.w * col.k
                            height: col.mon.h * col.k
                            clip: true
                            Parchment { anchors.fill: parent; radius: 2; age: 0.5 }
                            Rectangle { anchors.fill: parent; z: 4; radius: 2; color: "transparent"
                                        border.width: col.current || root.hoverWs === col.wsId ? 2 : 0
                                        border.color: root.hoverWs === col.wsId ? Theme.arcane : Theme.gold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.goTo(col.wsId) }
                            Ribbon { visible: col.current; x: tile.width - 34; y: -2; z: 5; width: 16; length: Math.min(60, tile.height * 0.35) }
                            Body { anchors.centerIn: parent; visible: col.windows.length === 0; text: "a blank page"; italic: true; color: Theme.inkDim }
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
                                    Rectangle { anchors.fill: parent; color: Theme.leatherDark; border.width: winMouse.containsMouse ? 2 : 1
                                                border.color: winMouse.containsMouse ? Theme.goldBright : Theme.alpha(Theme.goldDeep, 0.9) }
                                    ScreencopyView { id: preview; anchors.fill: parent; anchors.margins: 1
                                                     captureSource: OverviewState.open ? win.modelData.wayland : null; live: true }
                                    IconImage { anchors.centerIn: parent; visible: !preview.hasContent; implicitSize: Math.min(32, parent.height - 6)
                                                source: root.appIcon(win.ipc.class ?? "") }
                                    MouseArea {
                                        id: winMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        property point pressAt
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
                                            } else root.focusWindow(win.modelData);
                                        }
                                    }
                                }
                            }
                        }
                        Row {
                            spacing: 10
                            Text { text: "Chapter " + Theme.roman(col.wsId); color: col.current ? Theme.goldBright : Theme.fg
                                   font.family: Theme.uncial; font.pixelSize: 17 }
                            Body { anchors.verticalCenter: parent.verticalCenter; text: col.windows.length ? col.windows.length + (col.windows.length === 1 ? " page" : " pages") : ""
                                   italic: true; color: Theme.alpha(Theme.fg, 0.6); font.pixelSize: 13 }
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
}
