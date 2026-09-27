import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import "../theme"

// 3 · Orbital workspaces. Workspaces are planets on a tilted elliptical orbit around a small brass
// star; the orbit turns so this monitor's active workspace always sits at the front, glowing brass.
// Planets further back are smaller and dimmer. Each window on a workspace is a moon circling it.
// Click a planet to go there (the orbit swings it round), scroll over the orbit to step through.
// Beside the orbit: the focused window, as a small-caps class and a mono title.
Item {
    id: root

    required property ShellScreen screen
    // Only animate the moons while the panel can be seen
    property bool running: true

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1

    // Planets: 1..orbitCount always, plus any higher workspace in use
    readonly property var ids: {
        const out = [];
        for (let i = 1; i <= Theme.orbitCount; i++) out.push(i);
        for (const w of Hyprland.workspaces.values)
            if (w.id > Theme.orbitCount && !out.includes(w.id)) out.push(w.id);
        if (activeId > 0 && !out.includes(activeId)) out.push(activeId);
        return out.sort((a, b) => a - b);
    }

    function workspace(id) { return Hyprland.workspaces.values.find(w => w.id === id) ?? null; }
    function go(id) { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`); }

    // ---------------------------------------------------------------- orbit rotation
    // rot = the angle added to every planet's slot; the active one is turned to the front (+90°)
    property real rot: target
    readonly property real step: 2 * Math.PI / ids.length
    property real target: 0
    function aim() {
        const i = Math.max(0, ids.indexOf(activeId));
        let t = Math.PI / 2 - i * step;
        // the short way round from where the orbit is now
        while (t - rot > Math.PI) t -= 2 * Math.PI;
        while (t - rot < -Math.PI) t += 2 * Math.PI;
        target = t;
    }
    onActiveIdChanged: aim()
    onIdsChanged: aim()
    Component.onCompleted: { aim(); rot = target; }
    Behavior on rot { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

    // Moons: one slow phase shared by every planet
    property real phase: 0
    NumberAnimation on phase {
        from: 0
        to: 2 * Math.PI
        duration: Theme.moonPeriod
        loops: Animation.Infinite
        running: root.running
    }

    // Window lists change without the workspace list changing
    property int toplevelTick: 0
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root.toplevelTick++; }
    }

    // ---------------------------------------------------------------- geometry
    readonly property real ocx: Theme.orbitRx + Theme.planetActive + 6
    readonly property real ocy: height / 2 + Theme.orbitDrop
    property int hovered: -1

    // Where planet i is right now: {x, y, z (0 back .. 1 front), r}
    function place(i) {
        const a = i * step + rot;
        const z = (Math.sin(a) + 1) / 2;
        const id = ids[i];
        const r = (id === activeId ? Theme.planetActive
                                   : Theme.planetMin + (Theme.planetMax - Theme.planetMin) * z);
        return { x: ocx + Theme.orbitRx * Math.cos(a), y: ocy + Theme.orbitRy * Math.sin(a), z: z, r: r };
    }

    // ---------------------------------------------------------------- drawing
    Item {
        id: orbitLayer
        width: root.ocx * 2
        height: root.height

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative

            function ellipseHalf(ctx, front) {
                ctx.beginPath();
                ctx.ellipse(root.ocx - Theme.orbitRx, root.ocy - Theme.orbitRy, Theme.orbitRx * 2, Theme.orbitRy * 2);
                // Canvas ellipse() has no start/end; clip to the half instead
            }

            function planet(ctx, i, p) {
                const id = root.ids[i];
                const ws = root.workspace(id);
                const active = id === root.activeId;
                const occupied = (ws?.toplevels?.values?.length ?? 0) > 0;
                const urgent = ws?.urgent ?? false;
                const depth = 0.4 + 0.6 * p.z;

                // Moons behind the planet first
                const moons = ws?.toplevels?.values?.length ?? 0;
                const drawMoons = behind => {
                    for (let k = 0; k < moons; k++) {
                        const ma = root.phase * (1 + (i % 3) * 0.25) + k * 2 * Math.PI / moons + i;
                        const s = Math.sin(ma);
                        if ((s < 0) !== behind) continue;
                        const mr = p.r + Theme.moonGap;
                        ctx.fillStyle = Theme.alpha(active ? Theme.brassBright : Theme.phosphor,
                                                    depth * (behind ? 0.45 : 0.95));
                        ctx.beginPath();
                        ctx.arc(p.x + mr * Math.cos(ma), p.y + mr * 0.45 * s, Theme.moonRadius, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                };
                drawMoons(true);

                // The planet: active = polished brass, occupied = slate with a brass rim, empty = a ring
                if (active) {
                    const g = ctx.createRadialGradient(p.x - p.r * 0.35, p.y - p.r * 0.4, 0.5, p.x, p.y, p.r);
                    g.addColorStop(0, Theme.brassBright);
                    g.addColorStop(0.6, Theme.brass);
                    g.addColorStop(1, Theme.brassDeep);
                    ctx.fillStyle = g;
                } else if (occupied) {
                    const g = ctx.createRadialGradient(p.x - p.r * 0.35, p.y - p.r * 0.4, 0.5, p.x, p.y, p.r);
                    g.addColorStop(0, Theme.alpha(Theme.hover, depth));
                    g.addColorStop(1, Theme.alpha(Theme.bgDark, depth));
                    ctx.fillStyle = g;
                } else {
                    ctx.fillStyle = Theme.alpha(Theme.bgDark, 0.85 * depth);
                }
                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r, 0, 2 * Math.PI);
                ctx.fill();
                ctx.lineWidth = i === root.hovered ? 1.6 : 1;
                ctx.strokeStyle = urgent ? Theme.signal
                                : active ? Theme.brassBright
                                : i === root.hovered ? Theme.brass
                                : Theme.alpha(occupied ? Theme.brass : Theme.brassDeep, depth);
                ctx.stroke();

                drawMoons(false);

                // Numeral above, fading towards the back of the orbit
                ctx.fillStyle = Theme.alpha(active ? Theme.brassBright : Theme.fg, active ? 1 : 0.2 + 0.5 * p.z);
                ctx.font = `${active ? 600 : 400} ${Theme.dataSizeSmall}px "${Theme.fontData}"`;
                ctx.textAlign = "center";
                ctx.fillText(String(id), p.x, p.y - p.r - 3);
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const n = root.ids.length;
                const places = root.ids.map((_, i) => root.place(i));
                const order = places.map((p, i) => i).sort((a, b) => places[a].z - places[b].z);

                const orbit = alpha => {
                    ctx.strokeStyle = Theme.alpha(Theme.brass, alpha);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.ellipse(root.ocx - Theme.orbitRx, root.ocy - Theme.orbitRy, Theme.orbitRx * 2, Theme.orbitRy * 2);
                    ctx.stroke();
                };

                // Back half of the orbit, the back planets, the star, then the front
                ctx.save();
                ctx.beginPath();
                ctx.rect(0, 0, width, root.ocy);
                ctx.clip();
                orbit(0.22);
                ctx.restore();
                for (const i of order) if (places[i].z < 0.5) planet(ctx, i, places[i]);

                const sg = ctx.createRadialGradient(root.ocx, root.ocy, 0, root.ocx, root.ocy, Theme.starRadius * 3);
                sg.addColorStop(0, Theme.alpha(Theme.brassBright, 0.95));
                sg.addColorStop(0.3, Theme.alpha(Theme.brass, 0.5));
                sg.addColorStop(1, Theme.alpha(Theme.brass, 0));
                ctx.fillStyle = sg;
                ctx.beginPath();
                ctx.arc(root.ocx, root.ocy, Theme.starRadius * 3, 0, 2 * Math.PI);
                ctx.fill();

                ctx.save();
                ctx.beginPath();
                ctx.rect(0, root.ocy, width, height);
                ctx.clip();
                orbit(0.5);
                ctx.restore();
                for (const i of order) if (places[i].z >= 0.5) planet(ctx, i, places[i]);
            }

            Connections {
                target: root
                function onRotChanged() { canvas.requestPaint(); }
                function onPhaseChanged() { canvas.requestPaint(); }
                function onIdsChanged() { canvas.requestPaint(); }
                function onActiveIdChanged() { canvas.requestPaint(); }
                function onHoveredChanged() { canvas.requestPaint(); }
                function onToplevelTickChanged() { canvas.requestPaint(); }
            }
            Connections {
                target: Theme
                function onPaletteChanged() { canvas.requestPaint(); }
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.brass
            shadowBlur: 0.35
            shadowOpacity: 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 12
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.hovered >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

            function hit(mx, my) {
                // front-most planet under the cursor (with a little slack)
                let best = -1, bz = -1;
                for (let i = 0; i < root.ids.length; i++) {
                    const p = root.place(i);
                    const d = Math.hypot(mx - p.x, my - p.y);
                    if (d <= p.r + 5 && p.z > bz) { best = i; bz = p.z; }
                }
                return best;
            }
            onPositionChanged: mouse => root.hovered = hit(mouse.x, mouse.y)
            onExited: root.hovered = -1
            onClicked: mouse => {
                const i = hit(mouse.x, mouse.y);
                if (i >= 0) root.go(root.ids[i]);
            }
            onWheel: wheel => {
                const i = root.ids.indexOf(root.activeId);
                const n = root.ids.length;
                root.go(root.ids[(i + (wheel.angleDelta.y < 0 ? 1 : n - 1)) % n]);
            }
        }
    }

    // ---------------------------------------------------------------- focused window
    Column {
        anchors.left: orbitLayer.right
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: -2
        width: Math.max(0, Math.min(Theme.windowTitleWidth, root.width - orbitLayer.width - 18))
        visible: width > 60 && Hyprland.activeToplevel !== null && Hyprland.focusedMonitor === root.monitor

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: (Hyprland.activeToplevel?.wayland?.appId ?? Hyprland.activeToplevel?.lastIpcObject?.class ?? "").toLowerCase()
            color: Theme.brass
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize - 1
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: Hyprland.activeToplevel?.title ?? ""
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }
}
