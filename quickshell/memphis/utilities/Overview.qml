import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"

// The workspace overview, as a 98 window: each workspace a little desktop (the desktop colour, in
// a sunken frame) with live previews of its windows, each with a tiny caption. Click a window to
// switch to it, click a desktop to go there, drag a window onto another desktop to move it, 1-9 to
// go, Esc closes. qs ipc call overview toggle (or right-click the workspace buttons).
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
    function appIcon(cls) {
        const e = DesktopEntries.heuristicLookup(cls);
        return e?.icon || "application-x-executable";
    }
    function monitorSize(mon) {
        const o = mon?.lastIpcObject ?? {};
        const w = o.width ?? mon?.width ?? 1920, h = o.height ?? mon?.height ?? 1080;
        const s = o.scale ?? 1;
        return (o.transform ?? 0) % 2 === 1 ? { w: h / s, h: w / s, x: o.x ?? 0, y: o.y ?? 0 }
                                             : { w: w / s, h: h / s, x: o.x ?? 0, y: o.y ?? 0 };
    }

    screen: focusedScreen
    visible: OverviewState.open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "memphis-overview"
    WlrLayershell.keyboardFocus: OverviewState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: OverviewState
        function onOpenChanged() {
            if (OverviewState.open) { Hyprland.refreshMonitors(); Hyprland.refreshToplevels(); scope.forceActiveFocus(); }
            root.dragging = null;
        }
    }
    Timer { id: refreshSoon; interval: 150; onTriggered: Hyprland.refreshToplevels() }

    Dither { anchors.fill: parent; a: "#000000"; b: "transparent"; opacity: 0.35 }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onPressed: e => {
            const n = e.key - Qt.Key_0;
            if (n >= 1 && n <= 9) { root.goTo(n); e.accepted = true; }
        }
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Win {
            id: frame
            readonly property int cols: Math.min(root.count, 5)
            readonly property var mon: root.monitorSize(Hyprland.focusedMonitor)
            readonly property real tileW: Math.min(340, (root.width - 160) / cols)
            readonly property real tileH: tileW * mon.h / mon.w
            anchors.centerIn: parent
            width: cols * (tileW + 14) + 26
            height: Math.ceil(root.count / cols) * (tileH + 40) + Theme.titleHeight + 60
            title: "Workspaces"
            icon: "preferences-desktop"
            status: `${Hyprland.toplevels.values.length} window(s) on ${root.count} workspaces   ·   drag a window to move it`
            onCloseRequested: root.close()
            MouseArea { anchors.fill: parent }

            Grid {
                id: grid
                x: 10; y: 10
                columns: frame.cols
                spacing: 14
                Repeater {
                    model: root.count
                    Column {
                        id: col
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                        readonly property var mon: root.monitorSize(ws?.monitor ?? Hyprland.focusedMonitor)
                        readonly property real k: frame.tileW / mon.w
                        readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId)
                        readonly property bool current: Hyprland.focusedWorkspace?.id === wsId
                        spacing: 4

                        Rectangle {
                            // drop target / current: a highlight-colour ring round the frame
                            width: frame.tileW + 6
                            height: frame.tileH + 6
                            color: root.hoverWs === col.wsId || col.current ? Theme.select : "transparent"
                            Bevel {
                                id: tile
                                x: 3; y: 3
                                width: frame.tileW
                                height: frame.tileH
                                kind: "sunken"
                                fill: Theme.desktop
                                clip: true
                                function contains(p) { const q = mapFromItem(null, p.x, p.y); return q.x >= 0 && q.y >= 0 && q.x < width && q.y < height; }
                                MouseArea { anchors.fill: parent; onClicked: root.goTo(col.wsId) }
                                Repeater {
                                    model: col.windows
                                    Item {
                                        id: win
                                        required property var modelData
                                        readonly property var ipc: modelData.lastIpcObject ?? {}
                                        x: ((ipc.at?.[0] ?? 0) - col.mon.x) * col.k
                                        y: ((ipc.at?.[1] ?? 0) - col.mon.y) * col.k
                                        width: Math.max(30, (ipc.size?.[0] ?? 200) * col.k)
                                        height: Math.max(24, (ipc.size?.[1] ?? 150) * col.k)
                                        z: ipc.floating ? 2 : 1
                                        opacity: root.dragging === modelData ? 0.3 : 1
                                        Bevel { anchors.fill: parent; kind: "raised"; fill: Theme.face }
                                        // a tiny caption
                                        Rectangle {
                                            x: 2; y: 2; width: parent.width - 4; height: 12
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: win.modelData.activated ? Theme.title : Theme.inactiveTitle }
                                                GradientStop { position: 1; color: win.modelData.activated ? Theme.title2 : Theme.inactiveTitle2 }
                                            }
                                        }
                                        ScreencopyView {
                                            id: preview
                                            x: 2; y: 15
                                            width: parent.width - 4
                                            height: parent.height - 17
                                            captureSource: OverviewState.open ? win.modelData.wayland : null
                                            live: true
                                        }
                                        Icon {
                                            anchors.centerIn: preview
                                            visible: !preview.hasContent && preview.height > 20
                                            name: root.appIcon(win.ipc.class ?? "")
                                            size: Math.min(32, preview.height - 4)
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            property point pressAt
                                            onPressed: e => pressAt = Qt.point(e.x, e.y)
                                            onPositionChanged: e => {
                                                if (!pressed) return;
                                                if (!root.dragging && Math.hypot(e.x - pressAt.x, e.y - pressAt.y) > 6) root.dragging = win.modelData;
                                                if (root.dragging) {
                                                    root.dragPos = mapToItem(null, e.x, e.y);
                                                    root.hoverWs = -1;
                                                    for (const c of grid.children)
                                                        if (c.hits && c.hits(root.dragPos)) root.hoverWs = c.wsId;
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
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: col.current
                            text: "Workspace " + col.wsId + (col.windows.length ? "  (" + col.windows.length + ")" : "")
                        }
                        function hits(p) { return tile.contains(p); }
                    }
                }
            }
        }
    }

    // the dragged window, following the pointer
    Bevel {
        visible: root.dragging !== null
        x: root.dragPos.x - 40
        y: root.dragPos.y - 20
        width: 80; height: 40
        kind: "raised"
        fill: Theme.face
        opacity: 0.85
        Icon { anchors.centerIn: parent; name: root.appIcon(root.dragging?.lastIpcObject?.class ?? ""); size: 24 }
    }
}
