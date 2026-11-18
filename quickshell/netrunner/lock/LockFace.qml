import QtQuick
import Quickshell
import "../theme"
import "../widgets"
import "../services"

// What every monitor shows while locked: the game's flatline. Locking, the desktop (a snapshot from
// just before) drains to red and collapses into a line across the middle while a heartbeat traces
// along it, each beat weaker, until it flatlines and FLATLINED stamps over it (shaders/ekg.frag).
// Locked, it's a monitor: the EKG sweeping across, a slow sleeping pulse, the clock and the BPM over
// it, and on the main screen the passphrase line. Each key kicks a beat (and the pulse quickens);
// a wrong passphrase throws a burst of arrhythmia in red; the cooldown is a flat red line. Right: the
// trauma team revives you, two defibrillator jolts (white flashes, huge spikes), and the line splits
// open top and bottom onto the desktop as its colour comes back.
// (The black ICE face it replaced is lock/LockFace.qml.old.)
Item {
    id: root

    property string screenName: ""
    property bool main: true
    property bool preview: false

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ---------------------------------------------------------------- the clocks
    Driver { id: intro; until: Theme.lockIntro }
    Driver { id: outro; until: LockState.leaveKind === "unlock" ? Theme.lockOutro : Theme.lockClose }
    Driver { id: alertFx; until: 1400 }
    property real time: 0
    property real head: 0                    // the write head, 0..1 across the screen
    property real bpm: 54
    property real phase: 0                   // to the next beat
    property var beats: []                   // [{ x, amp }]: amp < 0 is arrhythmic
    function beat(amp) {
        const h = head;
        // drop what the head is about to write over, keep the newest seven
        const keep = beats.filter(b => { const age = ((h - b.x) % 1 + 1) % 1; return age < 0.88 && age > 0.002; }).slice(-7);
        beats = keep.concat([{ x: h, amp: amp }]);
    }
    FrameAnimation {
        running: root.visible
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 20);
            root.time += dt;
            const sweep = intro.running ? 1.7 : 4.0;          // seconds to cross the screen
            root.head = (root.head + dt / sweep) % 1;
            const flat = LockState.coolLeft > 0 || root.unlocking || root.before || (intro.running && intro.ms > 1000);
            root.bpm = Math.max(54, root.bpm - dt * 5);
            if (!flat && !intro.running) {
                root.phase += dt * root.bpm / 60;
                if (root.phase >= 1) { root.phase = 0; root.beat(0.75); }
            }
        }
    }
    Connections {
        target: LockState
        function onRevealedChanged() {
            if (LockState.revealed && !LockState.leaving) {
                outro.stop(); root.beats = []; root.head = 0.04; root.bpm = 54;
                intro.play(); introBeats.n = 0; introBeats.restart(); clockText.replay();
            }
        }
        function onLeavingChanged() {
            if (!LockState.leaving) return;
            intro.stop();
            outro.play();
            if (LockState.leaveKind === "unlock") { jolt.n = 0; jolt.restart(); }
        }
        function onStatusChanged() {
            if (LockState.status === "denied" || LockState.status === "error") { alertFx.play(); arrhythmia.n = 0; arrhythmia.restart(); }
            if (LockState.status === "cooldown") alertFx.play();
        }
        function onBufferChanged() {
            if (LockState.buffer.length > root.lastLength && LockState.coolLeft === 0) { root.bpm = Math.min(120, root.bpm + 7); root.beat(1.0); root.phase = 0; }
            root.lastLength = LockState.buffer.length;
        }
    }
    property int lastLength: 0
    // the intro's dying heartbeat: three beats, each weaker, then nothing
    Timer {
        id: introBeats
        property int n: 0
        interval: n === 0 ? 380 : 260
        onTriggered: { root.beat([1.1, 0.7, 0.35][n]); n++; if (n < 3) restart(); }
    }
    // a wrong passphrase: a burst of arrhythmia
    Timer {
        id: arrhythmia
        property int n: 0
        interval: 150
        onTriggered: { root.beat(-1.3); n++; if (n < 3) restart(); }
    }
    // the defibrillator: two jolts
    Timer {
        id: jolt
        property int n: 0
        interval: n === 0 ? 20 : 200
        onTriggered: { root.beat(n === 0 ? 2.4 : 3.0); n++; if (n < 2) restart(); }
    }

    readonly property bool hasShot: shot.status === Image.Ready
    readonly property bool unlocking: LockState.leaving && LockState.leaveKind === "unlock"
    readonly property bool before: !LockState.revealed && !LockState.leaving && hasShot
    readonly property real i: intro.ms
    readonly property real o: outro.ms
    readonly property real squeeze: before ? 0
        : intro.running ? (hasShot ? Theme.inOut(Theme.seg(i, 0, 520)) : 1)
        : outro.running ? (unlocking ? 1 - Theme.inOut(Theme.seg(o, 450, 1050)) : 1 - Theme.inOut(Theme.seg(o, 40, 380)))
        : LockState.leaving ? 0 : 1
    readonly property real drain: before ? 0 : intro.running ? (hasShot ? Theme.seg(i, 0, 380) : 1)
        : outro.running ? 1 - Theme.seg(o, unlocking ? 500 : 60, unlocking ? 1050 : 380) : LockState.leaving ? 0 : 1
    readonly property real flash: unlocking && outro.running ? Math.max(1 - Theme.seg(o, 0, 120), Theme.seg(o, 200, 215) * (1 - Theme.seg(o, 215, 340))) : 0
    readonly property real traceOn: before ? 0 : intro.running ? Theme.seg(i, 300, 420) : outro.running ? 1 - Theme.seg(o, unlocking ? 450 : 0, unlocking ? 700 : 200) : LockState.leaving ? 0 : 1
    readonly property real build: intro.running ? Theme.out3(Theme.seg(i, 1000, 1300)) : outro.running ? 1 - Theme.seg(o, 0, unlocking ? 260 : 150) : LockState.leaving ? 0 : 1
    readonly property bool bad: LockState.status === "denied" || LockState.status === "error" || LockState.status === "cooldown"
    readonly property real alert: (alertFx.running ? 1 - Theme.seg(alertFx.ms, 700, 1400) : 0) + (LockState.coolLeft > 0 ? 0.6 : 0)
    function packed(k) {
        const b = root.beats, at = n => b[n] ?? { x: 0, amp: 0 };
        return Qt.vector4d(at(2 * k).x, at(2 * k).amp, at(2 * k + 1).x, at(2 * k + 1).amp);
    }

    // ---------------------------------------------------------------- the monitor
    Rectangle { anchors.fill: parent; color: Theme.bgDark }
    Item {
        id: shotLayer
        anchors.fill: parent
        visible: false
        Image {
            id: shot
            anchors.fill: parent
            cache: false
            source: root.screenName ? LockState.shotPath(root.screenName) : ""
        }
    }
    ShaderEffectSource { id: shotTex; sourceItem: shotLayer; hideSource: true; live: true }
    ShaderEffect {
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../shaders/ekg.frag.qsb")
        property vector2d size: Qt.vector2d(width, height)
        property real squeeze: root.squeeze
        property real drain: root.drain
        property real flash: root.flash
        property real alert: Math.min(1, root.alert)
        property real head: root.head
        property real time: root.time
        property real hasShot: root.hasShot ? 1 : 0
        property real trace: root.traceOn
        property vector4d b0: root.packed(0)
        property vector4d b1: root.packed(1)
        property vector4d b2: root.packed(2)
        property vector4d b3: root.packed(3)
        property color line: Theme.cyan
        property color red: Theme.red
        property color base: Qt.tint(Theme.bgDark, Theme.alpha(Theme.red, 0.04))
        property var shot: shotTex
    }

    // the words over it: FLATLINED as it dies, REVIVING as it comes back
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * 0.16
        visible: intro.running && root.i > 900 || root.unlocking && root.o < 520
        readonly property real k: intro.running ? Theme.seg(root.i, 900, 960) * (1 - Theme.seg(root.i, 1180, 1300)) : 1 - Theme.seg(root.o, 380, 520)
        opacity: k * (Math.random() < 0.12 ? 0.35 : 1)
        scale: intro.running ? 1.25 - 0.25 * Theme.out3(Theme.seg(root.i, 900, 1000)) : 1
        text: intro.running ? "FLATLINED" : root.o < 200 ? "CLEAR" : "REVIVING"
        color: intro.running ? Theme.red : Theme.cyan
        font.family: Theme.display; font.pixelSize: 96; font.weight: Font.Bold; font.letterSpacing: 14
        style: Text.Outline; styleColor: Theme.bgDark
    }

    // ---------------------------------------------------------------- the face
    Item {
        id: face
        anchors.fill: parent
        opacity: root.build
        visible: opacity > 0.01

        Column {
            x: 36; y: 36
            spacing: 8
            Hazard { width: 96; height: 10 }
            Row {
                spacing: 14
                Label { text: "NEURAL LINK"; strong: true; color: Theme.bright }
                Label { text: "//  SUSPENDED"; strong: true; color: Theme.red }
            }
            Jp { text: "神経接続停止 // 生命維持" }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 36
            y: 40
            spacing: 8
            Label { anchors.right: parent.right; text: "HOST " + Status.host + "  //  UPLINK " + (Net.ssid || "WIRED") }
            Label { anchors.right: parent.right; text: "PROFILE  //  " + (Status.profile || "—") }
        }

        // the clock
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.13
            spacing: 4
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                Scramble {
                    id: clockText
                    target: Qt.formatTime(clock.date, "HH:mm")
                    duration: 420
                    color: Theme.bright
                    font.family: Theme.display; font.pixelSize: 140; font.weight: Font.Bold
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 28
                    text: Qt.formatTime(clock.date, "ss")
                    color: Theme.red
                    font.family: Theme.display; font.pixelSize: 34; font.weight: Font.Bold
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Label { text: Qt.formatDate(clock.date, "ddd  MM.dd.yy"); strong: true; color: Theme.fg }
                Label { text: "//"; color: Theme.alpha(Theme.dim, 0.6) }
                Label { text: "OPERATOR " + LockState.user; strong: true; color: Theme.cyan }
            }
        }

        // the vitals over the line
        Row {
            x: 60
            y: root.height / 2 - root.height * 0.15
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f05f6}"
                color: root.alert > 0.05 ? Theme.red : Theme.cyan
                font.family: Theme.mono; font.pixelSize: 30
                scale: 1 + 0.25 * Math.max(0, 1 - root.phase * 6)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: LockState.coolLeft > 0 ? "---" : Math.round(root.bpm); color: Theme.bright; font.family: Theme.display; font.pixelSize: 34; font.weight: Font.Bold }
                Label { text: "BPM"; color: Theme.cyan; strong: true }
            }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 60
            y: root.height / 2 - root.height * 0.15
            spacing: 4
            Label { anchors.right: parent.right; text: "SPO2  98%   //   RESP  12"; color: Theme.fg; strong: true }
            Label { anchors.right: parent.right; text: LockState.coolLeft > 0 ? "VITALS  //  FLATLINE" : "VITALS  //  STABLE"; color: LockState.coolLeft > 0 ? Theme.red : Theme.cyan }
            Label { anchors.right: parent.right; text: "SESSION SUSPENDED  //  AWAITING REVIVAL" }
        }

        // the passphrase (main screen)
        Item {
            id: auth
            visible: root.main
            width: 620
            height: 128
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height / 2 + root.height * 0.17 + (1 - root.build) * 40
            transform: Translate { x: root.shake }

            Chamfer { anchors.fill: parent; cut: 14; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.86); stroke: root.bad ? Theme.red : Theme.alpha(Theme.cyan, 0.5) }
            Row {
                x: 18; y: 14
                spacing: 10
                Tag { anchors.verticalCenter: parent.verticalCenter; text: "TRAUMA"; height: 18; pixelSize: 10; color: root.bad ? Theme.red : Theme.cyan }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "AUTHORIZE REVIVAL"; strong: true; color: Theme.bright }
                Jp { anchors.verticalCenter: parent.verticalCenter; text: "認証" }
            }
            Label {
                anchors.right: parent.right; anchors.rightMargin: 18; y: 16
                text: LockState.attempts > 0 ? "FAILED " + LockState.attempts : "BUFFER " + LockState.buffer.length
                color: LockState.attempts > 0 ? Theme.red : Theme.dim
            }
            // a byte per character (random: they say nothing about what was typed)
            Row {
                x: 18; y: 46
                spacing: 5
                Repeater {
                    model: Math.min(14, LockState.buffer.length)
                    Rectangle {
                        required property int index
                        width: 36; height: 26
                        color: Theme.alpha(root.bad ? Theme.red : Theme.cyan, 0.16)
                        border.width: 1; border.color: root.bad ? Theme.red : Theme.cyan
                        Text {
                            anchors.centerIn: parent
                            text: ((LockState.session * 131 + index * 97 + 41) % 256).toString(16).toUpperCase().padStart(2, "0")
                            color: Theme.bright
                            font.family: Theme.mono; font.pixelSize: 12; font.weight: Font.Bold
                        }
                    }
                }
                Rectangle {
                    width: 12; height: 26
                    color: "transparent"
                    visible: LockState.status !== "verifying"
                    Rectangle { anchors.bottom: parent.bottom; width: 12; height: 3; color: Theme.red; opacity: Math.round(root.time * 2) % 2 }
                }
            }
            Label {
                x: 18
                anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                text: LockState.status === "verifying" ? "VERIFYING  //  CHARGING PADDLES…"
                    : LockState.coolLeft > 0 ? "FLATLINE  //  TRY AGAIN IN " + LockState.coolLeft + " S"
                    : LockState.status === "denied" ? "ACCESS DENIED  //  ARRHYTHMIA"
                    : LockState.status === "error" ? "AUTH ERROR  //  " + (LockState.detail || "TRY AGAIN")
                    : LockState.status === "granted" ? "REVIVAL AUTHORIZED"
                    : root.preview ? "PREVIEW  //  ESC CLOSES" : "ENTER REVIVES THE SESSION  //  ESC CLEARS"
                color: root.bad ? Theme.red : LockState.status === "verifying" || LockState.status === "granted" ? Theme.cyan : Theme.dim
            }
        }

        Row {
            x: 24
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
            spacing: 24
            Label { text: "QUEUE " + Queue.cleared + "/" + Queue.total + " CLEARED" }
            Label { text: Status.auditAvailable ? "VULN " + Status.vulnCount + " AFFECTED" : "VULN SCAN OFFLINE"; strong: true; color: Theme.fg }
            Label { text: "ICE " + Status.ice }
        }
        Label {
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.bottom: parent.bottom; anchors.bottomMargin: 20
            text: "SESSION " + Status.session
        }
    }
    readonly property real shake: alertFx.running ? Math.sin(alertFx.ms / 18) * 10 * (1 - Theme.seg(alertFx.ms, 0, 500)) : 0
}
