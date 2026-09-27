import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme"
import "../../services"
import ".."

// Chronometer: pomodoro (focus, short and long breaks, rounds shown as planets) or a plain countdown.
// A big dial: the remaining time as a draining brass arc, a sweeping second hand, the time in the
// middle. The timer keeps running with the deck closed (services/FocusTimer.qml); a beacon on the
// horizon shows it.
Column {
    id: root

    spacing: 22

    readonly property bool pomodoro: FocusTimer.mode === "pomodoro"
    readonly property color ink: !root.pomodoro || FocusTimer.phase === "focus" ? Theme.brassBright : Theme.phosphor

    Row {
        spacing: 8
        Link { text: "pomodoro"; primary: root.pomodoro; onClicked: FocusTimer.setMode("pomodoro") }
        Link { text: "timer"; primary: !root.pomodoro; onClicked: FocusTimer.setMode("timer") }
    }

    // ---------------------------------------------------------------- the dial
    Item {
        width: parent.width
        height: Theme.chronoDial * 2 + 20

        Item {
            id: dial
            width: Theme.chronoDial * 2
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10

            Canvas {
                id: face
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = width / 2, r = c - 6;
                    const top = -Math.PI / 2;
                    ctx.fillStyle = Theme.alpha(Theme.bg, 0.95);
                    ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.fill();
                    ctx.strokeStyle = Theme.brass;
                    ctx.lineWidth = 1.6;
                    ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.stroke();
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.35);
                    ctx.lineWidth = 0.8;
                    ctx.beginPath(); ctx.arc(c, c, r - 26, 0, 2 * Math.PI); ctx.stroke();
                    // graduations: 60 minute marks
                    for (let i = 0; i < 60; i++) {
                        const a = top + i / 60 * 2 * Math.PI, big = i % 5 === 0;
                        ctx.strokeStyle = Theme.alpha(Theme.brass, big ? 0.9 : 0.4);
                        ctx.lineWidth = big ? 1.5 : 0.8;
                        const r2 = r - (big ? 12 : 6);
                        ctx.beginPath();
                        ctx.moveTo(c + (r - 2) * Math.cos(a), c + (r - 2) * Math.sin(a));
                        ctx.lineTo(c + r2 * Math.cos(a), c + r2 * Math.sin(a));
                        ctx.stroke();
                    }
                    // remaining time, draining clockwise from the top
                    const f = FocusTimer.progress;
                    ctx.strokeStyle = root.ink;
                    ctx.lineWidth = 5;
                    ctx.lineCap = "round";
                    if (f > 0.002) {
                        ctx.beginPath();
                        ctx.arc(c, c, r - 19, top, top + f * 2 * Math.PI);
                        ctx.stroke();
                    }
                    ctx.lineCap = "butt";
                    // second hand
                    const s = (FocusTimer.remaining % 60) / 60;          // second hand
                    const a = top + s * 2 * Math.PI;
                    ctx.strokeStyle = Theme.alpha(Theme.signal, 0.9);
                    ctx.lineWidth = 1.2;
                    // (only its outer end, so it never crosses the readout)
                    ctx.beginPath();
                    ctx.moveTo(c + (r - 50) * Math.cos(a), c + (r - 50) * Math.sin(a));
                    ctx.lineTo(c + (r - 28) * Math.cos(a), c + (r - 28) * Math.sin(a));
                    ctx.stroke();
                    ctx.fillStyle = Theme.signal;
                    ctx.beginPath(); ctx.arc(c + (r - 50) * Math.cos(a), c + (r - 50) * Math.sin(a), 2.5, 0, 2 * Math.PI); ctx.fill();
                }
                Connections {
                    target: FocusTimer
                    function onRemainingChanged() { face.requestPaint(); }
                    function onDurationChanged() { face.requestPaint(); }
                    function onPhaseChanged() { face.requestPaint(); }
                }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: root.ink; shadowBlur: 0.5; shadowOpacity: 0.5
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 18
            }

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: FocusTimer.phaseLabel.toLowerCase()
                    color: root.ink
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize + 2
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing * 2
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: FocusTimer.remainingText
                    color: Theme.starlight
                    font.family: Theme.fontData
                    font.pixelSize: 38
                    font.weight: Font.Light
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: FocusTimer.running ? "running" : FocusTimer.active ? "paused" : "ready"
                    color: FocusTimer.running ? Theme.phosphor : Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
        }
    }

    // Rounds as planets: filled = done, ringed = this one
    Row {
        visible: root.pomodoro
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14
        Repeater {
            model: FocusTimer.rounds
            Rectangle {
                required property int index
                readonly property bool done: index < FocusTimer.completed
                readonly property bool now: index === FocusTimer.completed && FocusTimer.phase === "focus"
                width: 14; height: 14; radius: 7
                color: done ? Theme.brass : "transparent"
                border.width: now ? 2 : 1
                border.color: now ? Theme.brassBright : Theme.alpha(Theme.brass, 0.6)
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 22
        Knob { glyph: "\u{f0450}"; label: "reset"; onClicked: FocusTimer.reset() }
        Knob {
            glyph: FocusTimer.running ? "\u{f03e4}" : "\u{f040a}"
            label: FocusTimer.running ? "pause" : "start"
            size: 56
            active: FocusTimer.running
            onClicked: FocusTimer.toggle()
        }
        Knob { glyph: "\u{f04ad}"; label: "skip"; onClicked: FocusTimer.skip() }
    }

    // ---------------------------------------------------------------- settings
    Section {
        title: root.pomodoro ? "lengths" : "countdown"
        Repeater {
            model: root.pomodoro ? [["focus", "focus"], ["short break", "short"], ["long break", "long"]] : []
            Stepper {
                required property var modelData
                label: modelData[0]
                value: FocusTimer.phaseMins(modelData[1])
                onChanged: v => FocusTimer.setPhaseMins(modelData[1], v)
            }
        }
        Stepper {
            visible: root.pomodoro
            label: "rounds before a long break"
            unit: ""
            value: FocusTimer.rounds
            onChanged: v => FocusTimer.rounds = Math.max(1, Math.min(12, v))
        }
        Item {
            visible: root.pomodoro
            width: parent.width
            height: 28
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "start the next phase by itself"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: FocusTimer.autoStart
                onToggled: FocusTimer.autoStart = !FocusTimer.autoStart
            }
        }
        Stepper {
            visible: !root.pomodoro
            label: "minutes"
            value: FocusTimer.timerMins
            onChanged: v => FocusTimer.setTimerMins(v)
        }
        Flow {
            visible: !root.pomodoro
            width: parent.width
            spacing: 6
            Repeater {
                model: [5, 10, 15, 25, 45, 60, 90]
                Link {
                    required property int modelData
                    mono: true
                    text: modelData + " min"
                    primary: FocusTimer.timerMins === modelData
                    onClicked: FocusTimer.setTimerMins(modelData)
                }
            }
        }
    }

    component Stepper: Item {
        id: st
        property string label
        property string unit: " min"
        property int value
        signal changed(int v)
        width: parent.width
        height: 30
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: st.label
            color: Theme.fg
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Link { text: "−"; mono: true; onClicked: st.changed(st.value - 1) }
            Text {
                width: 60
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: st.value + st.unit
                color: Theme.brassBright
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSize
            }
            Link { text: "+"; mono: true; onClicked: st.changed(st.value + 1) }
        }
    }
}
