import QtQuick
import QtQuick.Effects
import Quickshell
import "../theme"

// 2 · Sundial clock, in the horizon bar's dome. A graduated ring: the brass arc sweeps from the
// top through the current hour (it's full at :59), the gnomon points at the hour on a 12-hour dial,
// a phosphor bead runs round with the seconds. Day and date sit either side in small caps, the
// digital time underneath in mono.
Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property real cx: width / 2
    readonly property real cy: Theme.sundialCenterY

    // ---------------------------------------------------------------- the dial
    Item {
        id: dialLayer
        anchors.fill: parent

        Canvas {
            id: dial
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = root.cx, cy = root.cy, R = Theme.sundialRadius;
                const m = clock.minutes, s = clock.seconds, h = clock.hours % 12;
                const top = -Math.PI / 2;
                const turn = a => top + a * 2 * Math.PI;

                // Face: a dark disc so the dial reads over the line
                ctx.fillStyle = Theme.alpha(Theme.bgDark, 0.9);
                ctx.beginPath();
                ctx.arc(cx, cy, R + Theme.sundialTickMajor + 2, 0, 2 * Math.PI);
                ctx.fill();

                // Base ring
                ctx.strokeStyle = Theme.alpha(Theme.brassDeep, 0.9);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.arc(cx, cy, R, 0, 2 * Math.PI);
                ctx.stroke();

                // Minute graduations; the ones already passed this hour are lit
                for (let i = 0; i < 60; i++) {
                    const a = turn(i / 60), major = i % 5 === 0;
                    const r1 = R + 2, r2 = R + 2 + (major ? Theme.sundialTickMajor : Theme.sundialTick);
                    ctx.strokeStyle = i <= m ? Theme.alpha(Theme.brass, major ? 0.95 : 0.7)
                                             : Theme.alpha(Theme.brassDeep, major ? 0.8 : 0.5);
                    ctx.lineWidth = major ? 1.2 : 0.8;
                    ctx.beginPath();
                    ctx.moveTo(cx + r1 * Math.cos(a), cy + r1 * Math.sin(a));
                    ctx.lineTo(cx + r2 * Math.cos(a), cy + r2 * Math.sin(a));
                    ctx.stroke();
                }

                // The sweep: how far through the hour we are
                const sweep = (m + s / 60) / 60;
                ctx.strokeStyle = Theme.brass;
                ctx.lineWidth = Theme.sundialSweepWidth;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.arc(cx, cy, R - Theme.sundialSweepWidth / 2 - 1, top, turn(Math.max(sweep, 0.004)));
                ctx.stroke();
                ctx.lineCap = "butt";

                // Gnomon: the hour, as a tapered brass needle from the pivot
                const ha = turn((h + m / 60) / 12), hl = R - Theme.sundialSweepWidth - 4;
                const nx = Math.cos(ha), ny = Math.sin(ha), px = -ny, py = nx;
                ctx.fillStyle = Theme.brassBright;
                ctx.beginPath();
                ctx.moveTo(cx + nx * hl, cy + ny * hl);
                ctx.lineTo(cx + px * 1.8, cy + py * 1.8);
                ctx.lineTo(cx - nx * 3, cy - ny * 3);
                ctx.lineTo(cx - px * 1.8, cy - py * 1.8);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = Theme.brassDeep;
                ctx.beginPath();
                ctx.arc(cx, cy, 2, 0, 2 * Math.PI);
                ctx.fill();

                // Seconds: a phosphor bead riding the ring
                const sa = turn(s / 60);
                ctx.fillStyle = Theme.phosphor;
                ctx.beginPath();
                ctx.arc(cx + R * Math.cos(sa), cy + R * Math.sin(sa), 1.8, 0, 2 * Math.PI);
                ctx.fill();
            }

            Connections {
                target: clock
                function onDateChanged() { dial.requestPaint(); }
            }
            Connections {
                target: Theme
                function onPaletteChanged() { dial.requestPaint(); }
            }
            onWidthChanged: requestPaint()
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.brass
            shadowBlur: 0.4
            shadowOpacity: 0.55
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 16
        }
    }

    // ---------------------------------------------------------------- readouts
    Text {
        id: day
        anchors.right: parent.horizontalCenter
        anchors.rightMargin: Theme.sundialRadius + Theme.sundialTickMajor + 10
        y: root.cy - height / 2 - 1
        text: Qt.formatDateTime(clock.date, "ddd").toLowerCase()
        color: Theme.brass
        font.family: Theme.fontLabel
        font.pixelSize: Theme.labelSize
        font.capitalization: Font.SmallCaps
        font.letterSpacing: Theme.labelSpacing
        font.weight: Font.DemiBold
    }
    Text {
        anchors.left: parent.horizontalCenter
        anchors.leftMargin: Theme.sundialRadius + Theme.sundialTickMajor + 10
        y: day.y
        text: Qt.formatDateTime(clock.date, "d MMM").toLowerCase()
        color: Theme.brass
        font.family: Theme.fontLabel
        font.pixelSize: Theme.labelSize
        font.capitalization: Font.SmallCaps
        font.letterSpacing: Theme.labelSpacing
        font.weight: Font.DemiBold
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + Theme.sundialRadius + Theme.sundialTickMajor + 3
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.fg
        font.family: Theme.fontData
        font.pixelSize: Theme.dataSizeSmall
        font.letterSpacing: 1.5
    }
}
