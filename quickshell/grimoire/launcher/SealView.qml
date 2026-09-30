import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../theme"
import "seal.js" as SealGen

// A program's seal (launcher/seal.js says what each part means), drawn out in ink as if by pen:
// the sigil first, then the signs round it, the tick band, and the ring, which stays open by a
// hair until `closed` (casting), when the last stroke meets its start and the seal glows.
Item {
    id: root

    property var app: null
    property int uses: 0
    property bool closed: false
    property color ink: Theme.ink
    property color glowColor: Theme.arcane
    readonly property var seal: app ? SealGen.make(app, uses) : null

    // how far along the drawing is: 0 .. 1 over every stroke but the last hair of the ring
    property real drawn: 0
    property real closing: closed ? 1 : 0
    Behavior on closing { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    readonly property var starts: {
        const out = [];
        let acc = 0;
        for (const s of seal?.strokes ?? []) { out.push(acc); acc += s.len; }
        return out;
    }
    readonly property real total: (seal?.strokes ?? []).reduce((a, s) => a + s.len, 0)
    readonly property real gap: seal ? seal.strokes[seal.strokes.length - 1].len * 0.05 : 0
    readonly property real at: drawn * (total - gap) + closing * gap

    // a new seal: start again, at a steady pen speed (a busier seal takes a little longer)
    // (the same program again, e.g. its use count went up as it was summoned: no need to redraw)
    property string drawnFor: ""
    onSealChanged: {
        const id = app?.id ?? "";
        if (seal && id === drawnFor) return;
        drawnFor = id;
        pen.stop();
        drawn = 0;
        pen.duration = Math.max(900, Math.min(1900, total * 0.55));
        if (seal) pen.start();
    }
    NumberAnimation { id: pen; target: root; property: "drawn"; from: 0; to: 1; easing.type: Easing.InOutSine }

    Item {
        id: field
        width: 200; height: 200
        scale: Math.min(root.width, root.height) / 200
        transformOrigin: Item.TopLeft
        x: (root.width - Math.min(root.width, root.height)) / 2
        y: (root.height - Math.min(root.width, root.height)) / 2

        Repeater {
            model: root.seal ? root.seal.strokes.length : 0
            Shape {
                id: stroke
                required property int index
                readonly property var s: root.seal.strokes[index]
                readonly property real frac: s.len > 0 ? Math.max(0, Math.min(1, (root.at - root.starts[index]) / s.len)) : 1
                anchors.fill: parent
                visible: frac > 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.ink
                    strokeWidth: stroke.s.w
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: SealGen.partial(stroke.s, stroke.frac) }
                }
            }
        }
    }

    // the pen's point: a bead of fresh ink where the line is being drawn
    readonly property var tip: {
        const st = seal?.strokes ?? [];
        if (!seal || drawn >= 1 || drawn <= 0) return null;
        for (let i = 0; i < st.length; i++) {
            if (at < starts[i] + st[i].len) {
                const d = SealGen.partial(st[i], (at - starts[i]) / st[i].len).split(" ");
                return [parseFloat(d[d.length - 2]), parseFloat(d[d.length - 1])];
            }
        }
        return null;
    }
    Rectangle {
        visible: root.tip !== null
        readonly property real k: field.scale
        width: 7; height: 7; radius: 3.5
        x: field.x + (root.tip?.[0] ?? 0) * k - 3.5
        y: field.y + (root.tip?.[1] ?? 0) * k - 3.5
        color: Theme.alpha(root.glowColor, 0.75)
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.6; blurMax: 12 }
    }

    // cast: the finished seal glows
    layer.enabled: true
    layer.samples: 4
    layer.effect: MultiEffect {
        shadowEnabled: root.closing > 0
        shadowColor: root.glowColor
        shadowOpacity: 0.9 * root.closing
        shadowBlur: 0.6
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        blurMax: 24
    }
}
