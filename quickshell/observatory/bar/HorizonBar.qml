import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// 1 · Horizon bar. A 2px glowing brass line along the top of the screen, graduated like an
// instrument scale. Hover the top edge (or `qs ipc call horizon toggle`) and it drops into a
// ~36px translucent panel with a dome in the middle; the line becomes the panel's lower edge.
//
// The panel is one shape driven by `reveal` (0 = line, 1 = open): its height is reveal x barHeight,
// so at 0 the "panel" is just its lower edge sitting on the top of the screen.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    // Anything that needs the panel held open (a popup, a drag) sets this
    property bool holdOpen: false

    readonly property bool open: HorizonState.pinned || holdOpen || hover.hovered || hideTimer.running
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

    // Geometry shared by the fill, the line and the input mask
    // While music plays, the collapsed line drops a little so the waveform can swing both ways
    readonly property real lineY: Theme.lineTop + Theme.lineWidth / 2 + reveal * Theme.barHeight
                                  + Radio.gain * (1 - reveal) * Theme.waveAmplitude
    readonly property real dome: reveal * Theme.bulgeDepth
    readonly property real cx: width / 2
    readonly property real bw: Theme.bulgeWidth

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.windowDepth
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "observatory-horizon"

    // Input: just a strip along the top edge while collapsed; the panel and dome while open
    mask: Region {
        item: bar.reveal > 0.02 ? panelHit : trigger
        Region { item: bar.reveal > 0.02 ? domeHit : null }
        Region { item: beacons.visible ? beacons : null }
    }
    Item { id: trigger; width: bar.width; height: Theme.triggerHeight }
    Item { id: panelHit; width: bar.width; height: bar.lineY + Theme.lineWidth + 4 }
    Item {
        id: domeHit
        x: bar.cx - bar.bw / 2
        width: bar.bw
        height: bar.lineY + bar.dome + 4
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) hideTimer.restart()
    }
    Timer { id: hideTimer; interval: Theme.hideDelay }

    // The lower contour as a list of path commands, shared by fill (SVG) and line (Canvas).
    // Straight across, then a smooth bell-shaped dome under the centre.
    function contour() {
        const y = lineY, d = dome, a = cx - bw / 2, b = cx + bw / 2, k = bw * 0.24;
        return [
            ["M", 0, y],
            ["L", a, y],
            ["C", a + k, y, cx - k, y + d, cx, y + d],
            ["C", cx + k, y + d, b - k, y, b, y],
            ["L", width, y],
        ];
    }

    // ---------------------------------------------------------------- panel fill
    Shape {
        id: fill
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: Math.min(1, bar.reveal * 1.6)

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: Theme.barHeight + Theme.bulgeDepth
                GradientStop { position: 0; color: Theme.panelTop }
                GradientStop { position: 1; color: Theme.panel }
            }
            PathSvg {
                path: {
                    const c = bar.contour();
                    let s = `M 0 0 L ${bar.width} 0 L ${bar.width} ${bar.lineY} `;
                    // the contour backwards, right to left
                    s += `L ${c[3][5]} ${c[3][6]} `;
                    s += `C ${c[3][3]} ${c[3][4]} ${c[3][1]} ${c[3][2]} ${c[2][5]} ${c[2][6]} `;
                    s += `C ${c[2][3]} ${c[2][4]} ${c[2][1]} ${c[2][2]} ${c[1][1]} ${c[1][2]} `;
                    s += `L 0 ${bar.lineY} Z`;
                    return s;
                }
            }
        }
    }

    // ---------------------------------------------------------------- the horizon line
    Item {
        id: lineLayer
        anchors.fill: parent

        Canvas {
            id: line
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, y = bar.lineY;
                const fade = Math.min(Theme.edgeFade / w, 0.3);

                // Brass fading in from both screen edges, brightest at the centre
                const g = ctx.createLinearGradient(0, 0, w, 0);
                g.addColorStop(0, Theme.alpha(Theme.brass, 0));
                g.addColorStop(fade, Theme.brass);
                g.addColorStop(0.5, Theme.brassBright);
                g.addColorStop(1 - fade, Theme.brass);
                g.addColorStop(1, Theme.alpha(Theme.brass, 0));

                // 5 · Radio waveform: while music plays the straight parts of the line carry cava's
                // levels as an oscilloscope trace, bass beside the dome, treble towards the edges
                const radio = Radio.active;
                const bars = Radio.bars, nb = bars.length, amp = Theme.waveAmplitude * Radio.gain;
                const level = t => {           // t: 0 at the dome .. 1 at the screen edge
                    const f = t * (nb - 1), i = Math.floor(f), k = f - i;
                    const v = (bars[i] ?? 0) * (1 - k) + (bars[Math.min(nb - 1, i + 1)] ?? 0) * k;
                    const env = Math.min(1, t / 0.06) * Math.min(1, (1 - t) / 0.12);
                    return v * Math.max(0, env);
                };
                const wave = (from, to, len) => {   // x from -> to, t measured from the dome
                    const n = Math.max(2, Math.round(Math.abs(to - from) / Theme.waveStep));
                    let px = from, py = y;
                    for (let j = 1; j <= n; j++) {
                        const x = from + (to - from) * j / n;
                        const t = from === 0 ? (to - x) / len : (x - from) / len;
                        const dy = j === n ? 0 : (j % 2 ? 1 : -1) * amp * level(t);
                        // smooth: curve through midpoints
                        ctx.quadraticCurveTo(px, py, (px + x) / 2, (py + y + dy) / 2);
                        px = x; py = y + dy;
                    }
                    ctx.lineTo(to, y);
                };

                ctx.beginPath();
                const cs = bar.contour();
                const a0 = cs[1][1];
                ctx.moveTo(0, y);
                if (radio) wave(0, a0, a0); else ctx.lineTo(a0, y);
                for (const c of cs.slice(2, 4)) ctx.bezierCurveTo(c[1], c[2], c[3], c[4], c[5], c[6]);
                const b0 = cs[3][5];
                if (radio) wave(b0, w, w - b0); else ctx.lineTo(w, y);
                ctx.strokeStyle = g;
                ctx.lineWidth = Theme.lineWidth;
                ctx.stroke();

                // Graduations hanging off the straight parts, like the scale on a sextant
                ctx.strokeStyle = Theme.alpha(Theme.brass, Theme.tickOpacity * (0.7 + 0.3 * bar.reveal));
                ctx.lineWidth = 1;
                ctx.beginPath();
                const a = bar.cx - bar.bw / 2 - 6, b = bar.cx + bar.bw / 2 + 6;
                const n = Math.floor(bar.cx / Theme.tickSpacing);
                for (let i = -n; i <= n; i++) {
                    const x = Math.round(bar.cx + i * Theme.tickSpacing) + 0.5;
                    if ((x > a && x < b) || x < Theme.edgeFade * 0.5 || x > w - Theme.edgeFade * 0.5)
                        continue;
                    const major = i % Theme.tickMajorEvery === 0;
                    ctx.moveTo(x, y + Theme.lineWidth / 2);
                    ctx.lineTo(x, y + Theme.lineWidth / 2 + (major ? Theme.tickMajorLength : Theme.tickLength));
                }
                ctx.stroke();

                // Engraved second rule just inside the panel, on the straight parts (open only)
                if (bar.reveal > 0.05) {
                    const ry = y - Theme.ruleInset;
                    const rg = ctx.createLinearGradient(0, 0, w, 0);
                    const ra = Theme.ruleOpacity * bar.reveal;
                    rg.addColorStop(0, Theme.alpha(Theme.brass, 0));
                    rg.addColorStop(fade * 1.5, Theme.alpha(Theme.brass, ra));
                    rg.addColorStop(1 - fade * 1.5, Theme.alpha(Theme.brass, ra));
                    rg.addColorStop(1, Theme.alpha(Theme.brass, 0));
                    ctx.strokeStyle = rg;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(0, ry + 0.5);
                    ctx.lineTo(a - 10, ry + 0.5);
                    ctx.moveTo(b + 10, ry + 0.5);
                    ctx.lineTo(w, ry + 0.5);
                    ctx.stroke();
                }

                // A small brass diamond hanging from the zenith (collapsed), where the dome will open
                const d = 3.5 * (1 - bar.reveal);
                if (d > 0.3) {
                    const dy = y + Theme.lineWidth / 2 + d;
                    ctx.fillStyle = Theme.brassBright;
                    ctx.beginPath();
                    ctx.moveTo(bar.cx, dy - d);
                    ctx.lineTo(bar.cx + d, dy);
                    ctx.lineTo(bar.cx, dy + d);
                    ctx.lineTo(bar.cx - d, dy);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            Connections {
                target: bar
                function onRevealChanged() { line.requestPaint(); }
                function onLineYChanged() { line.requestPaint(); }
                function onWidthChanged() { line.requestPaint(); }
            }
            Connections {
                target: Theme
                function onPaletteChanged() { line.requestPaint(); }
            }
            Connections {
                target: Radio
                function onBarsChanged() { line.requestPaint(); }
                function onGainChanged() { line.requestPaint(); }
            }
        }

        // Glow: a soft brass halo around whatever the canvas drew
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.brass
            shadowBlur: Math.min(1, Theme.glowBlur + Radio.level * Radio.gain * 0.4)
            shadowOpacity: Math.min(1, Theme.glowStrength + Radio.level * Radio.gain * 0.8)
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: Theme.glowRadius
            autoPaddingEnabled: true
        }
    }

    // ---------------------------------------------------------------- beacons (recording)
    Beacons {
        id: beacons
        x: Theme.beaconInset
        y: bar.lineY + Theme.lineWidth + 6
    }

    // ---------------------------------------------------------------- slots for components 2-4
    Item {
        id: slots
        width: bar.width
        height: Theme.barHeight
        y: (bar.reveal - 1) * Theme.barHeight * 0.4
        opacity: Math.max(0, (bar.reveal - 0.45) / 0.55)
        visible: opacity > 0

        // 3 · Orbital workspaces, and the focused window
        Orbits {
            id: leftSlot
            screen: bar.screen
            running: bar.reveal > 0
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: (bar.width - bar.bw) / 2 - 40
            height: parent.height
        }
        // 2 · Sundial, sitting on the horizon in the dome
        Sundial {
            id: centerSlot
            x: bar.cx - bar.bw / 2
            width: bar.bw
            height: Theme.barHeight + Theme.bulgeDepth
        }
        // 4 · Instrument cluster
        Instruments {
            id: rightSlot
            anchors.right: parent.right
            anchors.rightMargin: 24
            height: parent.height
        }
    }
}
