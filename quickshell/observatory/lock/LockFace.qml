import QtQuick
import QtQuick.Effects
import Quickshell
import "../theme"

// What a lock surface shows (the real lock and the preview use the same face): a slowly turning
// star field, a faint graduated hour circle, and in the middle a brass ring that takes the
// password. Each character typed lights a bead on the ring; while PAM checks, a phosphor arc
// sweeps round it; a wrong password turns it signal red and shakes it.
Item {
    id: root

    // Only the surface that has the keyboard shows the cursor line; all of them show the ring
    property bool preview: false

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real ringR: Theme.lockRing
    readonly property bool bad: LockState.status === "denied" || LockState.status === "error"
    readonly property color ink: bad ? Theme.signal : LockState.status === "granted" ? Theme.brassBright : Theme.brass

    // ---------------------------------------------------------------- sky
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.bgDark }
            GradientStop { position: 0.55; color: Theme.bg }
            GradientStop { position: 1; color: Theme.bgDark }
        }
    }

    // Two star layers turning about the centre at different speeds (a little parallax).
    // Each is drawn once into a square that covers the screen at any angle.
    Repeater {
        model: [
            { count: 1600, size: 0.9, speed: Theme.lockSkyPeriod, seed: 11, bright: 0.55 },
            { count: 260, size: 1.6, speed: Theme.lockSkyPeriod * 0.62, seed: 29, bright: 0.9 },
        ]
        Item {
            id: layerItem
            required property var modelData
            readonly property real side: Math.hypot(root.width, root.height)
            x: root.cx - side / 2
            y: root.cy - side / 2
            width: side
            height: side

            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    let seed = layerItem.modelData.seed;
                    const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
                    for (let i = 0; i < layerItem.modelData.count; i++) {
                        const x = rnd() * width, y = rnd() * height;
                        const r = (0.3 + rnd() * 0.7) * layerItem.modelData.size;
                        const tint = rnd();
                        const col = tint < 0.08 ? Theme.phosphor : tint < 0.14 ? Theme.brassBright : Theme.starlight;
                        ctx.fillStyle = Theme.alpha(col, (0.2 + rnd() * 0.8) * layerItem.modelData.bright);
                        ctx.beginPath();
                        ctx.arc(x, y, r, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                }
                onWidthChanged: requestPaint()
            }

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: layerItem.modelData.speed
                loops: Animation.Infinite
            }
        }
    }

    // Hour circle: a large faint graduated ring, static, like the dome's setting circle
    Canvas {
        id: hourCircle
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const R = Math.min(width, height) * 0.4, cx = root.cx, cy = root.cy;
            ctx.strokeStyle = Theme.alpha(Theme.brass, 0.16);
            ctx.lineWidth = 1;
            ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.stroke();
            ctx.beginPath(); ctx.arc(cx, cy, R * 0.62, 0, 2 * Math.PI); ctx.stroke();
            for (let d = 0; d < 360; d += 2) {
                const a = d * Math.PI / 180, big = d % 30 === 0, mid = d % 10 === 0;
                const l = big ? 14 : mid ? 8 : 4;
                ctx.strokeStyle = Theme.alpha(Theme.brass, big ? 0.4 : mid ? 0.22 : 0.12);
                ctx.beginPath();
                ctx.moveTo(cx + R * Math.cos(a), cy + R * Math.sin(a));
                ctx.lineTo(cx + (R - l) * Math.cos(a), cy + (R - l) * Math.sin(a));
                ctx.stroke();
            }
            ctx.fillStyle = Theme.alpha(Theme.brass, 0.4);
            ctx.font = `600 ${Theme.labelSize}px "${Theme.fontLabel}"`;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            for (let h = 0; h < 24; h += 3) {
                const a = -Math.PI / 2 + h / 24 * 2 * Math.PI;
                ctx.fillText(`${String(h).padStart(2, "0")}h`, cx + (R + 22) * Math.cos(a), cy + (R + 22) * Math.sin(a));
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // ---------------------------------------------------------------- the brass ring
    Item {
        id: ringLayer
        anchors.fill: parent

        // Shake on a wrong password
        property real shake: 0
        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: ringLayer; property: "shake"; to: -14; duration: 50 }
            NumberAnimation { target: ringLayer; property: "shake"; to: 11; duration: 70 }
            NumberAnimation { target: ringLayer; property: "shake"; to: -7; duration: 70 }
            NumberAnimation { target: ringLayer; property: "shake"; to: 4; duration: 60 }
            NumberAnimation { target: ringLayer; property: "shake"; to: 0; duration: 60 }
        }
        Connections {
            target: LockState
            function onAttemptsChanged() { if (root.bad) shakeAnim.restart(); }
        }
        transform: Translate { x: ringLayer.shake }

        // The verifying sweep
        property real sweep: 0
        NumberAnimation on sweep {
            from: 0; to: 2 * Math.PI; duration: 1100
            loops: Animation.Infinite
            running: LockState.status === "verifying"
        }

        Canvas {
            id: ring
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = root.cx, cy = root.cy, R = root.ringR;
                const top = -Math.PI / 2;

                // Plate behind the readouts
                const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, R + 24);
                g.addColorStop(0, Theme.alpha(Theme.bgDark, 0.92));
                g.addColorStop(0.85, Theme.alpha(Theme.bgDark, 0.85));
                g.addColorStop(1, Theme.alpha(Theme.bgDark, 0));
                ctx.fillStyle = g;
                ctx.beginPath(); ctx.arc(cx, cy, R + 24, 0, 2 * Math.PI); ctx.fill();

                // Double brass ring
                ctx.strokeStyle = root.ink;
                ctx.lineWidth = 2;
                ctx.beginPath(); ctx.arc(cx, cy, R, 0, 2 * Math.PI); ctx.stroke();
                ctx.strokeStyle = Theme.alpha(root.ink, 0.4);
                ctx.lineWidth = 1;
                ctx.beginPath(); ctx.arc(cx, cy, R - 10, 0, 2 * Math.PI); ctx.stroke();
                ctx.beginPath(); ctx.arc(cx, cy, R + 12, 0, 2 * Math.PI); ctx.stroke();

                // Graduations between the rings
                for (let i = 0; i < 72; i++) {
                    const a = top + i / 72 * 2 * Math.PI, big = i % 6 === 0;
                    ctx.strokeStyle = Theme.alpha(root.ink, big ? 0.9 : 0.45);
                    ctx.lineWidth = big ? 1.4 : 0.8;
                    ctx.beginPath();
                    ctx.moveTo(cx + R * Math.cos(a), cy + R * Math.sin(a));
                    ctx.lineTo(cx + (R + (big ? 10 : 5)) * Math.cos(a), cy + (R + (big ? 10 : 5)) * Math.sin(a));
                    ctx.stroke();
                }

                // One bead per character typed, clockwise from the top (wrapping every lap)
                const n = LockState.buffer.length, per = Theme.lockBeads;
                for (let i = 0; i < n; i++) {
                    const lap = Math.floor(i / per);
                    const a = top + (i % per + 0.5) / per * 2 * Math.PI;
                    const r = R - 5 - lap * 7;
                    ctx.fillStyle = Theme.phosphor;
                    ctx.beginPath(); ctx.arc(cx + r * Math.cos(a), cy + r * Math.sin(a), 3, 0, 2 * Math.PI); ctx.fill();
                }

                // Verifying: a phosphor arc sweeping round the outside
                if (LockState.status === "verifying") {
                    ctx.strokeStyle = Theme.phosphor;
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(cx, cy, R + 20, top + ringLayer.sweep, top + ringLayer.sweep + 1.1);
                    ctx.stroke();
                }
            }
            Connections {
                target: LockState
                function onBufferChanged() { ring.requestPaint(); }
                function onStatusChanged() { ring.requestPaint(); }
            }
            Connections {
                target: ringLayer
                function onSweepChanged() { ring.requestPaint(); }
            }
            onWidthChanged: requestPaint()
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.bad ? Theme.signal : Theme.brass
            shadowBlur: 0.6
            shadowOpacity: 0.8
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 24
        }

        // Readouts inside the ring
        Column {
            x: root.cx - width / 2
            y: root.cy - height / 2
            width: root.ringR * 1.5
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "observatory  ·  " + LockState.user
                color: Theme.alpha(Theme.brass, 0.85)
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSize
                font.capitalization: Font.SmallCaps
                font.letterSpacing: Theme.labelSpacing * 2
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.starlight
                font.family: Theme.fontLabel
                font.pixelSize: Theme.lockTimeSize
                font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
                color: Theme.fg
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSizeLarge
                font.capitalization: Font.SmallCaps
                font.letterSpacing: Theme.labelSpacing
            }
        }
    }

    // ---------------------------------------------------------------- status, under the ring
    Column {
        x: root.cx - width / 2
        y: root.cy + root.ringR + 38
        width: 560
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                switch (LockState.status) {
                case "verifying": return "verifying";
                case "denied": return "access denied";
                case "error": return "authentication error";
                case "granted": return "access granted";
                default: return LockState.buffer === "" ? "enter passphrase" : "enter  ›  unlock";
                }
            }
            color: root.bad ? Theme.signal : LockState.status === "verifying" ? Theme.phosphor : Theme.brass
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSizeLarge + 2
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing * 2
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: text !== ""
            text: root.bad ? (LockState.detail !== "" ? LockState.detail : "wrong password · type it again")
                : root.preview ? "preview · esc closes" : ""
            color: root.bad ? Theme.alpha(Theme.signal, 0.85) : Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSize
        }
    }
}
