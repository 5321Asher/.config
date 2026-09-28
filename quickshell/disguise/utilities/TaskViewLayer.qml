import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../flyouts"

// Task View: the screen goes dark and frosted; this desktop's windows as live thumbnails in the
// middle (click to switch, × to close), the desktops along the bottom (point at one to see its
// windows, click to go there, drag a window onto one to move it there, + for a new one).
// Esc closes, 1-9 go to that desktop.
PanelWindow {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    screen: focusedScreen
    visible: TaskView.open || fadeOut.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "disguise-taskview"
    WlrLayershell.keyboardFocus: TaskView.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int count: Math.max(2, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id))
    property int shownWs: Hyprland.focusedWorkspace?.id ?? 1
    property var dragging: null
    property point dragPos
    property int dropWs: -1

    function close() { TaskView.open = false; }
    function goTo(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws} })`); close(); }
    function monitorSize(mon) {
        const o = mon?.lastIpcObject ?? {};
        const w = o.width ?? mon?.width ?? 1920, h = o.height ?? mon?.height ?? 1080, s = o.scale ?? 1;
        return (o.transform ?? 0) % 2 === 1 ? { w: h / s, h: w / s, x: o.x ?? 0, y: o.y ?? 0 } : { w: w / s, h: h / s, x: o.x ?? 0, y: o.y ?? 0 };
    }
    Connections {
        target: TaskView
        function onOpenChanged() {
            if (TaskView.open) { Hyprland.refreshToplevels(); Hyprland.refreshMonitors(); root.shownWs = Hyprland.focusedWorkspace?.id ?? 1; keys.forceActiveFocus(); }
            root.dragging = null;
        }
    }

    Item {
        anchors.fill: parent
        opacity: TaskView.open ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fadeOut; duration: Theme.normal } }

        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.dark ? "#000000" : "#1c1c1c", Theme.dark ? 0.4 : 0.25) }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
            Keys.onPressed: e => { const n = e.key - Qt.Key_0; if (n >= 1 && n <= 9) { root.goTo(n); e.accepted = true; } }
            MouseArea { anchors.fill: parent; onClicked: root.close() }

            // ---------------------------------------------------- this desktop's windows
            Item {
                id: stage
                x: 40; y: 40
                width: parent.width - 80
                height: strip.y - 60
                readonly property var wins: Hyprland.toplevels.values.filter(t => t.workspace?.id === root.shownWs)
                // the grid that makes thumbnails biggest (they keep each window's shape roughly)
                readonly property var fit: {
                    const n = Math.max(1, wins.length);
                    let best = { cols: 1, w: 0 };
                    for (let c = 1; c <= n; c++) {
                        const r = Math.ceil(n / c);
                        const w = Math.min((width - (c - 1) * 24) / c, ((height - (r - 1) * 24) / r - 36) * 1.6, 520);
                        if (w > best.w) best = { cols: c, w: w };
                    }
                    return best;
                }
                Txt {
                    visible: stage.wins.length === 0
                    anchors.centerIn: parent
                    text: "No windows open on Desktop " + root.shownWs
                    color: "#ffffff"
                    size: Theme.subtitle
                }
                Grid {
                    anchors.centerIn: parent
                    columns: stage.fit.cols
                    spacing: 24
                    Repeater {
                        model: TaskView.open ? stage.wins : []
                        Item {
                            id: win
                            required property var modelData
                            width: stage.fit.w
                            height: stage.fit.w / 1.6 + 36
                            opacity: root.dragging === modelData ? 0.35 : 1
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -6
                                radius: Theme.radiusLarge + 4
                                color: wm.containsMouse ? Qt.alpha("#ffffff", 0.12) : "transparent"
                                border.width: win.modelData.activated ? 2 : 0
                                border.color: Qt.alpha("#ffffff", 0.6)
                            }
                            AppIcon { x: 4; y: 6; size: 20; name: Apps.iconFor(win.modelData) }
                            Txt { x: 32; y: 2; width: parent.width - 64; height: 28; text: win.modelData.title; color: "#ffffff" }
                            Rectangle {
                                id: frame
                                y: 36
                                width: parent.width
                                height: parent.height - 36
                                radius: Theme.radiusLarge
                                color: Qt.alpha(Theme.mica, 0.6)
                                clip: true
                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    captureSource: TaskView.open ? win.modelData.wayland : null
                                    live: true
                                    constraintSize: Qt.size(width, height)
                                }
                                AppIcon { anchors.centerIn: parent; visible: !shot.hasContent; size: 64; name: Apps.iconFor(win.modelData) }
                            }
                            MouseArea {
                                id: wm
                                anchors.fill: parent
                                hoverEnabled: true
                                property point pressAt
                                onPressed: e => pressAt = Qt.point(e.x, e.y)
                                onPositionChanged: e => {
                                    if (!pressed) return;
                                    if (!root.dragging && Math.hypot(e.x - pressAt.x, e.y - pressAt.y) > 8) root.dragging = win.modelData;
                                    if (root.dragging) { root.dragPos = mapToItem(null, e.x, e.y); root.dropWs = strip.wsAt(root.dragPos); }
                                }
                                onReleased: {
                                    if (root.dragging) {
                                        if (root.dropWs > 0 && root.dropWs !== root.shownWs)
                                            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${root.dropWs}, window = "address:${Apps.addr(win.modelData)}", follow = false })`);
                                        root.dragging = null; root.dropWs = -1;
                                        Qt.callLater(Hyprland.refreshToplevels);
                                    } else {
                                        Apps.focusWin(win.modelData);
                                        root.close();
                                    }
                                }
                            }
                            Btn {
                                visible: wm.containsMouse || hovered
                                anchors.right: parent.right
                                y: 2
                                width: 30; height: 30
                                kind: "subtle"; glyph: ""; glyphSize: 10
                                textColor: "#ffffff"
                                onClicked: Apps.closeWin(win.modelData)
                                Rectangle { anchors.fill: parent; radius: Theme.radius; color: Theme.closeRed; visible: parent.hovered; z: -1 }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------- the desktops
            Item {
                id: strip
                width: parent.width
                height: 170
                y: parent.height - height - 16
                readonly property var mon: root.monitorSize(Hyprland.focusedMonitor)
                readonly property real tileH: 96
                readonly property real tileW: tileH * mon.w / mon.h
                function wsAt(p) {
                    for (let i = 0; i < desks.count; i++) {
                        const it = desks.itemAt(i);
                        const q = it.mapFromItem(null, p.x, p.y);
                        if (q.x >= 0 && q.y >= 0 && q.x < it.width && q.y < it.height) return it.wsId;
                    }
                    return -1;
                }
                Acrylic {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - 40, deskRow.width + 32)
                    height: parent.height
                    tintAlpha: Theme.dark ? 0.8 : 0.75
                    MouseArea { anchors.fill: parent }
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 16
                        contentWidth: deskRow.width
                        clip: true
                        interactive: contentWidth > width
                        Row {
                            id: deskRow
                            spacing: 16
                            Repeater {
                                id: desks
                                model: root.count
                                Column {
                                    id: desk
                                    required property int index
                                    readonly property int wsId: index + 1
                                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                                    readonly property var mon: root.monitorSize(ws?.monitor ?? Hyprland.focusedMonitor)
                                    readonly property real k: strip.tileW / mon.w
                                    readonly property bool current: Hyprland.focusedWorkspace?.id === wsId
                                    spacing: 8
                                    Txt {
                                        text: "Desktop " + desk.wsId
                                        size: Theme.caption
                                        strong: desk.current
                                    }
                                    Rectangle {
                                        width: strip.tileW; height: strip.tileH
                                        radius: Theme.radiusLarge
                                        color: Theme.desktop
                                        clip: true
                                        border.width: root.dropWs === desk.wsId || dm.containsMouse || root.shownWs === desk.wsId ? 2 : desk.current ? 1 : 0
                                        border.color: root.dropWs === desk.wsId || root.shownWs === desk.wsId ? Theme.accent : Theme.strong
                                        Repeater {
                                            model: TaskView.open ? Hyprland.toplevels.values.filter(t => t.workspace?.id === desk.wsId) : []
                                            Rectangle {
                                                required property var modelData
                                                readonly property var ipc: modelData.lastIpcObject ?? {}
                                                x: ((ipc.at?.[0] ?? 0) - desk.mon.x) * desk.k
                                                y: ((ipc.at?.[1] ?? 0) - desk.mon.y) * desk.k
                                                width: Math.max(12, (ipc.size?.[0] ?? 200) * desk.k)
                                                height: Math.max(10, (ipc.size?.[1] ?? 150) * desk.k)
                                                radius: 3
                                                color: Theme.card
                                                border.width: 1
                                                border.color: Theme.cardStroke
                                                AppIcon { anchors.centerIn: parent; size: Math.min(16, parent.height - 2); name: Apps.iconFor(parent.modelData) }
                                            }
                                        }
                                        MouseArea {
                                            id: dm
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onContainsMouseChanged: if (containsMouse && !root.dragging) root.shownWs = desk.wsId
                                            onClicked: root.goTo(desk.wsId)
                                        }
                                    }
                                }
                            }
                            // + New desktop
                            Column {
                                spacing: 8
                                Txt { text: "New desktop"; size: Theme.caption }
                                Rectangle {
                                    width: strip.tileW; height: strip.tileH
                                    radius: Theme.radiusLarge
                                    color: nm.containsMouse ? Theme.subtle : "transparent"
                                    border.width: 1
                                    border.color: Theme.strong
                                    Glyph { anchors.centerIn: parent; g: ""; size: 22 }
                                    MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; onClicked: root.goTo(root.count + 1) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // the dragged window, following the pointer
        Rectangle {
            visible: root.dragging !== null
            x: root.dragPos.x - 60; y: root.dragPos.y - 36
            width: 120; height: 72
            radius: Theme.radiusLarge
            color: Qt.alpha(Theme.card, 0.9)
            border.width: 1; border.color: Theme.accent
            AppIcon { anchors.centerIn: parent; size: 32; name: root.dragging ? Apps.iconFor(root.dragging) : "" }
        }
    }
}
