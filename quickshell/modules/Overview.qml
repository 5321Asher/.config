import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Full-screen workspace overview with live window previews.
// Click a window to focus it, click a workspace to switch, drag a window onto another workspace to move it.
PanelWindow {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    // Toplevel being dragged, and where the ghost is
    property var dragging: null
    property point dragPos
    property int hoverWs: -1

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    function close() {
        OverviewState.open = false;
    }

    function dispatch(cmd) {
        Hyprland.dispatch(cmd);
    }

    function addr(t) {
        return t.address.startsWith("0x") ? t.address : "0x" + t.address;
    }

    function focusWindow(t) {
        dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`);
        close();
    }

    function goTo(ws) {
        dispatch(`hl.dsp.focus({ workspace = ${ws} })`);
        close();
    }

    function moveWindow(t, ws) {
        dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${addr(t)}" })`);
        // Positions only update in lastIpcObject when asked
        refreshSoon.restart();
    }

    function appIcon(cls) {
        const entry = DesktopEntries.heuristicLookup(cls);
        const name = entry?.icon || cls;
        return name && Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
    }

    // Logical size of a monitor, accounting for rotation and scale
    function monitorSize(mon) {
        const o = mon?.lastIpcObject ?? {};
        const w = o.width ?? mon?.width ?? 1920, h = o.height ?? mon?.height ?? 1080;
        const s = o.scale ?? 1;
        return (o.transform ?? 0) % 2 === 1 ? { w: h / s, h: w / s, x: o.x ?? 0, y: o.y ?? 0 } : { w: w / s, h: h / s, x: o.x ?? 0, y: o.y ?? 0 };
    }

    screen: focusedScreen
    visible: OverviewState.open || fade.opacity > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: OverviewState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: OverviewState.open ? null : noInput

    Region { id: noInput }

    Connections {
        target: OverviewState
        function onOpenChanged() {
            if (OverviewState.open) {
                Hyprland.refreshMonitors();
                Hyprland.refreshToplevels();
                scope.forceActiveFocus();
            }
            root.dragging = null;
        }
    }

    Timer {
        id: refreshSoon
        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    Item {
        id: fade

        anchors.fill: parent
        opacity: OverviewState.open ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.bgDark.r, Theme.bgDark.g, Theme.bgDark.b, 0.9)
        }

        FocusScope {
            id: scope

            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
                const n = event.key - Qt.Key_0;
                if (n >= 1 && n <= Config.workspaceCount) {
                    root.goTo(n);
                    event.accepted = true;
                }
            }

            // Click on the backdrop closes
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 24
                scale: OverviewState.open ? 1 : 0.94

                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "WORKSPACES"
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 4
                    color: Theme.dim
                }

                Row {
                    id: cards

                    // Shared card height so every workspace fits across the screen
                    readonly property var sizes: Array.from({ length: Config.workspaceCount }, (_, i) => {
                        const ws = Hyprland.workspaces.values.find(w => w.id === i + 1);
                        return root.monitorSize(ws?.monitor ?? Hyprland.focusedMonitor);
                    })
                    readonly property real cardHeight: Math.min(root.height * 0.36,
                        (root.width - 160 - spacing * (Config.workspaceCount - 1)) / sizes.reduce((a, s) => a + s.w / s.h, 0))

                    spacing: 24

                    Repeater {
                        id: cardRepeater

                        model: Config.workspaceCount

                        Column {
                            id: col

                            required property int index
                            readonly property int wsId: index + 1
                            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                            readonly property var mon: cards.sizes[index]
                            readonly property real scaleFactor: card.height / mon.h
                            readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId)
                            readonly property bool current: Hyprland.focusedWorkspace?.id === wsId

                            spacing: 10

                            Rectangle {
                                id: card

                                width: cards.cardHeight * col.mon.w / col.mon.h
                                height: cards.cardHeight
                                radius: 0
                                clip: true
                                color: Theme.bg
                                border.width: col.current || root.hoverWs === col.wsId || cardMouse.containsMouse ? 2 : 1
                                border.color: root.hoverWs === col.wsId ? Theme.purple
                                    : col.current ? Theme.accent
                                    : cardMouse.containsMouse ? Theme.accent : Theme.border

                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: cardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.goTo(col.wsId)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: col.windows.length === 0
                                    text: "Empty"
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    color: Theme.border
                                }

                                // Windows, placed where they sit on the monitor
                                Repeater {
                                    model: col.windows

                                    Rectangle {
                                        id: win

                                        required property var modelData
                                        readonly property var ipc: modelData.lastIpcObject ?? {}
                                        readonly property bool isDragged: root.dragging === modelData

                                        x: ((ipc.at?.[0] ?? 0) - col.mon.x) * col.scaleFactor
                                        y: ((ipc.at?.[1] ?? 0) - col.mon.y) * col.scaleFactor
                                        width: Math.max(24, (ipc.size?.[0] ?? 200) * col.scaleFactor)
                                        height: Math.max(24, (ipc.size?.[1] ?? 150) * col.scaleFactor)
                                        z: ipc.floating ? 2 : 1
                                        radius: 0
                                        clip: true
                                        opacity: isDragged ? 0.3 : 1
                                        color: Theme.surface
                                        border.width: winMouse.containsMouse ? 2 : 1
                                        border.color: winMouse.containsMouse ? Theme.accent : Theme.hover

                                        ScreencopyView {
                                            id: preview
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            captureSource: OverviewState.open ? win.modelData.wayland : null
                                            live: true
                                        }

                                        // App icon badge (the whole preview when there's no capture)
                                        Rectangle {
                                            anchors.centerIn: preview.hasContent ? undefined : parent
                                            anchors.horizontalCenter: preview.hasContent ? parent.horizontalCenter : undefined
                                            anchors.bottom: preview.hasContent ? parent.bottom : undefined
                                            anchors.bottomMargin: 6
                                            readonly property int size: Math.min(preview.hasContent ? 30 : 44, win.width - 8, win.height - 8)
                                            width: size
                                            height: size
                                            radius: 0
                                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.8)
                                            visible: size >= 12

                                            Image {
                                                anchors.centerIn: parent
                                                source: root.appIcon(win.ipc.class ?? "")
                                                sourceSize.width: parent.size * 0.7
                                                sourceSize.height: parent.size * 0.7
                                            }
                                        }

                                        MouseArea {
                                            id: winMouse

                                            property point pressAt

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                            onPressed: e => pressAt = Qt.point(e.x, e.y)
                                            onPositionChanged: e => {
                                                if (!pressed)
                                                    return;
                                                if (!root.dragging && Math.hypot(e.x - pressAt.x, e.y - pressAt.y) > 6)
                                                    root.dragging = win.modelData;
                                                if (root.dragging) {
                                                    root.dragPos = mapToItem(fade, e.x, e.y);
                                                    root.hoverWs = cards.wsAt(root.dragPos);
                                                }
                                            }
                                            onReleased: {
                                                if (root.dragging) {
                                                    if (root.hoverWs > 0 && root.hoverWs !== col.wsId)
                                                        root.moveWindow(win.modelData, root.hoverWs);
                                                    root.dragging = null;
                                                    root.hoverWs = -1;
                                                } else {
                                                    root.focusWindow(win.modelData);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Label
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 0
                                    color: col.current ? Theme.surface : Theme.bgDark
                                    border.width: 1
                                    border.color: col.current ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: col.wsId
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: col.current ? Theme.accent : Theme.fg
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: col.windows.length === 0 ? "" : col.windows.length === 1 ? "1 window" : col.windows.length + " windows"
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    color: Theme.dim
                                }
                            }
                        }
                    }

                    // Workspace id under a point in `fade` coordinates, or -1
                    function wsAt(p) {
                        for (let i = 0; i < cardRepeater.count; i++) {
                            const col = cardRepeater.itemAt(i);
                            const c = col.children[0];
                            const local = c.mapFromItem(fade, p.x, p.y);
                            if (local.x >= 0 && local.y >= 0 && local.x <= c.width && local.y <= c.height)
                                return col.wsId;
                        }
                        return -1;
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Click a window to focus  ·  drag it to another workspace to move  ·  1–" + Config.workspaceCount + " to switch  ·  Esc to close"
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.border
                }
            }

            // Drag ghost
            Rectangle {
                visible: !!root.dragging
                x: root.dragPos.x - width / 2
                y: root.dragPos.y - height / 2
                width: 56
                height: 56
                radius: 0
                color: Theme.surface
                border.width: 2
                border.color: Theme.purple

                Image {
                    anchors.centerIn: parent
                    source: root.dragging ? root.appIcon(root.dragging.lastIpcObject?.class ?? "") : ""
                    sourceSize.width: 36
                    sourceSize.height: 36
                }
            }
        }
    }
}
