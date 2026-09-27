import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../theme"

// Survey: the workspace overview. Every workspace as a brass-framed plate with live window
// previews, laid out along a shallow arc like planets on an orrery. Click a window to focus it,
// click a plate to go there, drag a window onto another plate to move it, 1-5 to switch, Esc closes.
// Open with the star in the middle of the orbit, or: qs ipc call overview toggle
PanelWindow {
    id: root

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    property var dragging: null
    property point dragPos
    property int hoverWs: -1

    function close() { OverviewState.open = false; }
    function addr(t) { return t.address.startsWith("0x") ? t.address : "0x" + t.address; }
    function focusWindow(t) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`); close(); }
    function goTo(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws} })`); close(); }
    function moveWindow(t, ws) {
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${addr(t)}" })`);
        refreshSoon.restart();      // positions only update in lastIpcObject when asked
    }
    function appIcon(cls) {
        const entry = DesktopEntries.heuristicLookup(cls);
        const name = entry?.icon || cls;
        if (name.startsWith("/")) return "file://" + name;
        return name && Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
    }
    // Logical size of a monitor, accounting for rotation and scale
    function monitorSize(mon) {
        const o = mon?.lastIpcObject ?? {};
        const w = o.width ?? mon?.width ?? 1920, h = o.height ?? mon?.height ?? 1080;
        const s = o.scale ?? 1;
        return (o.transform ?? 0) % 2 === 1 ? { w: h / s, h: w / s, x: o.x ?? 0, y: o.y ?? 0 }
                                             : { w: w / s, h: h / s, x: o.x ?? 0, y: o.y ?? 0 };
    }

    screen: focusedScreen
    visible: OverviewState.open || stage.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-overview"
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
    Timer { id: refreshSoon; interval: 150; onTriggered: Hyprland.refreshToplevels() }

    Item {
        id: stage
        anchors.fill: parent
        opacity: OverviewState.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bgDark, Theme.chartDim + 0.2)
        }

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
                const n = event.key - Qt.Key_0;
                if (n >= 1 && n <= Theme.orbitCount) { root.goTo(n); event.accepted = true; }
            }

            MouseArea { anchors.fill: parent; onClicked: root.close() }

            // Heading
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: plates.y - height - 40
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "survey"
                    color: Theme.brass
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge + 8
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing * 3
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Hyprland.toplevels.values.length} bodies across ${Theme.orbitCount} orbits`
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }

            Item {
                id: plates
                readonly property var sizes: Array.from({ length: Theme.orbitCount }, (_, i) => {
                    const ws = Hyprland.workspaces.values.find(w => w.id === i + 1);
                    return root.monitorSize(ws?.monitor ?? Hyprland.focusedMonitor);
                })
                readonly property int gap: 30
                readonly property real plateHeight: Math.min(root.height * 0.3,
                    (root.width - 200 - gap * (Theme.orbitCount - 1)) / sizes.reduce((a, s) => a + s.w / s.h, 0))
                readonly property real totalWidth: sizes.reduce((a, s) => a + plateHeight * s.w / s.h, 0) + gap * (Theme.orbitCount - 1)
                x: (root.width - totalWidth) / 2
                y: (root.height - plateHeight) / 2 - Theme.overviewArc / 2
                width: totalWidth
                height: plateHeight + Theme.overviewArc + 40
                scale: OverviewState.open ? 1 : 0.95
                Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

                // Orbit arc behind the plates
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.alpha(Theme.brass, 0.35)
                        strokeWidth: 1
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [2, 6]
                        fillColor: "transparent"
                        startX: -60; startY: plates.plateHeight / 2 - 30
                        PathQuad {
                            x: plates.width + 60; y: plates.plateHeight / 2 - 30
                            controlX: plates.width / 2; controlY: plates.plateHeight / 2 + Theme.overviewArc * 2 - 30
                        }
                    }
                }

                Repeater {
                    id: plateRepeater
                    model: Theme.orbitCount

                    Item {
                        id: col
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property var mon: plates.sizes[index]
                        readonly property real w: plates.plateHeight * mon.w / mon.h
                        readonly property real scaleFactor: plates.plateHeight / mon.h
                        readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId)
                        readonly property bool current: Hyprland.focusedWorkspace?.id === wsId
                        readonly property bool hot: root.hoverWs === wsId || plateMouse.containsMouse
                        // position along the row, dipping on a shallow arc towards the middle
                        readonly property real px: plates.sizes.slice(0, index).reduce((a, s) => a + plates.plateHeight * s.w / s.h, 0) + plates.gap * index
                        readonly property real t: plates.width > 0 ? (px + w / 2) / plates.width * 2 - 1 : 0
                        x: px
                        y: Theme.overviewArc * (1 - t * t)
                        width: w
                        height: plates.plateHeight + 34

                        Item {
                            id: plate
                            width: col.w
                            height: plates.plateHeight
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.alpha(Theme.bg, 0.95)
                            }

                            MouseArea {
                                id: plateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.goTo(col.wsId)
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: col.windows.length === 0
                                text: "empty orbit"
                                color: Theme.alpha(Theme.brass, 0.4)
                                font.family: Theme.fontLabel
                                font.pixelSize: Theme.labelSize
                                font.capitalization: Font.SmallCaps
                                font.letterSpacing: Theme.labelSpacing
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
                                    radius: 2
                                    clip: true
                                    opacity: isDragged ? 0.3 : 1
                                    color: Theme.surface
                                    border.width: winMouse.containsMouse ? 1.5 : 1
                                    border.color: winMouse.containsMouse ? Theme.brassBright : Theme.alpha(Theme.brass, 0.3)

                                    ScreencopyView {
                                        id: preview
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: OverviewState.open ? win.modelData.wayland : null
                                        live: true
                                    }
                                    // App icon (the whole preview when there's no capture)
                                    Rectangle {
                                        anchors.centerIn: preview.hasContent ? undefined : parent
                                        anchors.horizontalCenter: preview.hasContent ? parent.horizontalCenter : undefined
                                        anchors.bottom: preview.hasContent ? parent.bottom : undefined
                                        anchors.bottomMargin: 6
                                        readonly property int size: Math.min(preview.hasContent ? 30 : 44, win.width - 8, win.height - 8)
                                        width: size
                                        height: size
                                        radius: size / 2
                                        color: Theme.alpha(Theme.bgDark, 0.85)
                                        border.width: 1
                                        border.color: Theme.alpha(Theme.brass, 0.6)
                                        visible: size >= 12
                                        IconImage {
                                            anchors.centerIn: parent
                                            implicitSize: parent.size * 0.62
                                            source: root.appIcon(win.ipc.class ?? "")
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
                                            if (!pressed) return;
                                            if (!root.dragging && Math.hypot(e.x - pressAt.x, e.y - pressAt.y) > 6)
                                                root.dragging = win.modelData;
                                            if (root.dragging) {
                                                root.dragPos = mapToItem(stage, e.x, e.y);
                                                root.hoverWs = plates.wsAt(root.dragPos);
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

                        // Frame: brass, corners cut, brighter for the current workspace or a drop target
                        Shape {
                            width: plate.width
                            height: plate.height
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: col.current || col.hot ? 2 : 1
                                strokeColor: root.hoverWs === col.wsId ? Theme.phosphor
                                    : col.current ? Theme.brassBright
                                    : col.hot ? Theme.brass : Theme.alpha(Theme.brass, 0.45)
                                fillColor: "transparent"
                                startX: Theme.chamfer; startY: 0.5
                                PathLine { x: plate.width - Theme.chamfer; y: 0.5 }
                                PathLine { x: plate.width - 0.5; y: Theme.chamfer }
                                PathLine { x: plate.width - 0.5; y: plate.height - Theme.chamfer }
                                PathLine { x: plate.width - Theme.chamfer; y: plate.height - 0.5 }
                                PathLine { x: Theme.chamfer; y: plate.height - 0.5 }
                                PathLine { x: 0.5; y: plate.height - Theme.chamfer }
                                PathLine { x: 0.5; y: Theme.chamfer }
                                PathLine { x: Theme.chamfer; y: 0.5 }
                            }
                            layer.enabled: col.current
                            layer.effect: MultiEffect {
                                shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.6; shadowOpacity: 0.8
                                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 20
                            }
                        }

                        // Label: number and window count
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: plate.height + 10
                            spacing: 10
                            Text {
                                text: col.wsId
                                color: col.current ? Theme.brassBright : Theme.fg
                                font.family: Theme.fontData
                                font.pixelSize: Theme.dataSize + 1
                                font.weight: col.current ? Font.DemiBold : Font.Normal
                            }
                            Text {
                                anchors.baseline: parent.children[0].baseline
                                text: col.windows.length === 0 ? "" : col.windows.length === 1 ? "1 body" : col.windows.length + " bodies"
                                color: Theme.dim
                                font.family: Theme.fontLabel
                                font.pixelSize: Theme.labelSize
                                font.capitalization: Font.SmallCaps
                                font.letterSpacing: Theme.labelSpacing
                            }
                        }
                    }
                }

                // Workspace id under a point in `stage` coordinates, or -1
                function wsAt(p) {
                    for (let i = 0; i < plateRepeater.count; i++) {
                        const c = plateRepeater.itemAt(i);
                        const local = c.mapFromItem(stage, p.x, p.y);
                        if (local.x >= 0 && local.y >= 0 && local.x <= c.w && local.y <= plates.plateHeight)
                            return c.wsId;
                    }
                    return -1;
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: plates.y + plates.height + 30
                text: "click a window to focus  ·  drag it to another orbit to move it  ·  1–" + Theme.orbitCount + " to switch  ·  esc to close"
                color: Theme.dim
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }

            // Drag ghost
            Rectangle {
                visible: !!root.dragging
                x: root.dragPos.x - width / 2
                y: root.dragPos.y - height / 2
                width: 56
                height: 56
                radius: 28
                color: Theme.alpha(Theme.bgDark, 0.9)
                border.width: 2
                border.color: Theme.phosphor
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 34
                    source: root.dragging ? root.appIcon(root.dragging.lastIpcObject?.class ?? "") : ""
                }
            }
        }
    }
}
