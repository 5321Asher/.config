import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../theme"
import "../utilities"

// The candle: your session's uptime. It is lit fresh at boot and burns down over Theme.candleHours
// to a stub, which keeps guttering however long you stay. Wax runs down its sides as it burns (a
// new run every twenty minutes or so, each creeping down when it forms, and now and then a single
// drop slides down from the rim), pools in the brass dish, and the flame (shaders/flame.frag, a
// real shader) never stops flickering or throwing its light on the leather. Reboot and it relights.
Item {
    id: root

    // seconds since boot (from /proc/uptime, re-read every minute)
    property real realUptime: 0
    readonly property real uptime: Debug.candleHours >= 0 ? Debug.candleHours * 3600 : realUptime
    readonly property real burnt: Math.min(1, uptime / (Theme.candleHours * 3600))
    readonly property real remaining: Math.max(0.1, 1 - burnt * 0.92)
    readonly property bool guttering: burnt >= 1

    readonly property real maxWax: Math.max(60, Math.min(280, height - 120))     // a fresh taper, in px
    readonly property real waxH: maxWax * remaining
    readonly property real waxW: 20
    readonly property real dishY: height - 34
    readonly property real waxTop: dishY + 4 - waxH
    readonly property color waxColor: Theme.mix(Theme.page, "#fffaf0", 0.35)

    FileView {
        id: up
        path: "/proc/uptime"
        onLoaded: root.realUptime = parseFloat(text().split(" ")[0]) || 0
    }
    Timer { running: true; repeat: true; interval: 60000; onTriggered: up.reload() }

    // ---------------------------------------------------------------- the light it throws
    Shape {
        id: light
        x: root.width / 2 - 110
        y: root.waxTop - 150
        width: 220; height: 260
        opacity: 0.55 * root.flicker
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 110; centerY: 110; centerRadius: 120
                focalX: 110; focalY: 110
                GradientStop { position: 0; color: Theme.alpha(Theme.flame, Theme.light ? 0.28 : 0.2) }
                GradientStop { position: 0.45; color: Theme.alpha(Theme.flame, 0.06) }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: 220; y: 0 }
            PathLine { x: 220; y: 260 }
            PathLine { x: 0; y: 260 }
            PathLine { x: 0; y: 0 }
        }
    }
    // a restless multiplier for the light (the shader flickers on its own)
    property real flicker: 1
    Behavior on flicker { NumberAnimation { duration: 140; easing.type: Easing.InOutSine } }
    Timer { running: true; repeat: true; interval: 150; onTriggered: root.flicker = 0.8 + Math.random() * 0.3 - (root.guttering ? Math.random() * 0.25 : 0) }

    // ---------------------------------------------------------------- the dish and the pool
    Item {
        id: dish
        width: 54; height: 22
        x: (root.width - width) / 2
        y: root.dishY
        // the handle ring, to the right
        Rectangle { x: parent.width - 8; y: 3; width: 14; height: 12; radius: 6; color: "transparent"; border.width: 2; border.color: Theme.goldDeep }
        // the dish: a shallow brass ellipse, lit from the flame above
        Rectangle {
            y: 6; width: parent.width; height: 14; radius: 7
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.goldBright }
                GradientStop { position: 0.45; color: Theme.gold }
                GradientStop { position: 1; color: Theme.goldDeep }
            }
            border.width: 1; border.color: Qt.darker(Theme.goldDeep, 1.3)
        }
        Rectangle { x: 4; y: 4; width: parent.width - 8; height: 8; radius: 4; color: Theme.mix(Theme.goldDeep, Theme.leatherDark, 0.3) }
        // the pool of wax, spreading as it burns
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -3
            y: 4
            width: root.waxW + 6 + (parent.width - 16 - root.waxW) * Math.min(1, root.burnt * 1.3)
            height: 7
            radius: 3.5
            color: Theme.mix(root.waxColor, Theme.pageDeep, 0.2)
        }
    }

    // ---------------------------------------------------------------- the candle
    Item {
        id: candle
        x: (root.width - root.waxW) / 2
        y: root.waxTop
        width: root.waxW
        height: root.waxH
        Behavior on height { NumberAnimation { duration: 2000; easing.type: Easing.InOutSine } }

        // the body: a cylinder of wax, lit from the front and warmer near the flame
        Rectangle {
            anchors.fill: parent
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.mix(root.waxColor, Theme.ink, 0.28) }
                GradientStop { position: 0.35; color: root.waxColor }
                GradientStop { position: 0.6; color: Theme.mix(root.waxColor, "#ffffff", 0.3) }
                GradientStop { position: 1; color: Theme.mix(root.waxColor, Theme.ink, 0.38) }
            }
        }
        // the glow through the wax at the top
        Rectangle {
            width: parent.width; height: Math.min(parent.height, 26)
            radius: 2
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.alpha(Theme.flame, 0.45 * root.flicker) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        // the melted cup at the top
        Rectangle { x: 1; y: -2; width: parent.width - 2; height: 5; radius: 2.5; color: Theme.mix(root.waxColor, Theme.flame, 0.25) }
        Rectangle { x: 3; y: -1; width: parent.width - 6; height: 3; radius: 1.5; color: Theme.alpha(Theme.flame, 0.35) }

        // runs of wax down the sides
        Repeater {
            model: root.drips
            Item {
                id: run
                required property var modelData
                readonly property real len: Math.min(root.waxH - 6, modelData.len * root.maxWax)
                x: modelData.side < 0 ? -2 : root.waxW - 5
                y: 0
                width: 7
                height: grown * len + 6
                property real grown: modelData.fresh ? 0 : 1
                NumberAnimation on grown { running: run.modelData.fresh; from: 0; to: 1; duration: 24000; easing.type: Easing.OutQuad }
                Rectangle {
                    x: run.modelData.side < 0 ? 0 : 1
                    width: 5; height: parent.height - 4
                    radius: 2.5
                    color: Theme.mix(root.waxColor, "#ffffff", run.modelData.side < 0 ? 0.05 : 0.25)
                    border.width: 0.5
                    border.color: Theme.alpha(Theme.ink, 0.18)
                }
                // the bead at the end
                Rectangle {
                    x: run.modelData.side < 0 ? -0.5 : 0.5
                    y: parent.height - 7
                    width: 6; height: 7; radius: 3
                    color: Theme.mix(root.waxColor, "#ffffff", 0.18)
                    border.width: 0.5
                    border.color: Theme.alpha(Theme.ink, 0.2)
                }
            }
        }

        // now and then a single drop slides down from the rim
        Rectangle {
            id: drop
            property real side: 1
            x: side < 0 ? -2 : root.waxW - 4
            width: 5; height: 6; radius: 2.5
            color: Theme.mix(root.waxColor, "#ffffff", 0.3)
            visible: slide.running
            SequentialAnimation {
                id: slide
                NumberAnimation { target: drop; property: "y"; from: -2; to: Math.max(10, root.waxH * 0.55); duration: 7000; easing.type: Easing.InQuad }
                NumberAnimation { target: drop; property: "opacity"; from: 1; to: 0; duration: 800 }
                PropertyAction { target: drop; property: "opacity"; value: 1 }
            }
        }
        Timer {
            running: !root.guttering
            repeat: true
            interval: 38000
            onTriggered: { drop.side = Math.random() < 0.5 ? -1 : 1; slide.restart(); }
        }
    }

    // the wick
    Rectangle {
        x: root.width / 2 - 1
        y: root.waxTop - 8
        width: 2; height: 10; radius: 1
        rotation: 6
        color: Theme.mix(Theme.ink, "#000000", 0.4)
        Rectangle { y: 0; width: 2; height: 3; radius: 1; color: Theme.alpha(Theme.flame, 0.9) }
    }

    // ---------------------------------------------------------------- the flame
    ShaderEffect {
        id: flame
        width: 54
        height: 112
        x: root.width / 2 - width / 2
        y: root.waxTop - height + 14
        property real time: 0
        property real seed: 0.37
        property real glow: 1.0
        property real gutter: root.guttering ? 0.8 : 0
        property color flameColor: Theme.flame
        fragmentShader: Theme.shaders + "flame.frag.qsb"
        NumberAnimation on time { from: 0; to: 3600; duration: 3600000; loops: Animation.Infinite }
    }

    // ---------------------------------------------------------------- the runs, from the uptime
    // One every ~20 minutes of burning, deterministic (the same session always has the same runs), on
    // alternate-ish sides, each some fraction of a fresh taper long. The newest creeps down as it forms.
    readonly property int runCount: Math.min(14, Math.floor(uptime / 1200))
    property int seenRuns: -1
    readonly property var drips: {
        const out = [];
        let s = 7;
        const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647; };
        for (let i = 0; i < runCount; i++) {
            out.push({ side: rnd() < 0.5 ? -1 : 1, len: 0.12 + rnd() * 0.32, fresh: seenRuns >= 0 && i >= seenRuns });
        }
        return out;
    }
    onRunCountChanged: seenTimer.restart()
    Timer { id: seenTimer; interval: 30000; onTriggered: root.seenRuns = root.runCount }
    Component.onCompleted: seenFirst.start()
    Timer { id: seenFirst; interval: 1500; onTriggered: root.seenRuns = root.runCount }

    function burnText() {
        const m = Math.floor(uptime / 60), h = Math.floor(m / 60);
        return h > 0 ? h + "h " + (m % 60) + "m" : m + "m";
    }
    function litAt() {
        const d = new Date(Date.now() - uptime * 1000);
        return Qt.formatTime(d, "h:mm") + (d.toDateString() === new Date().toDateString() ? " today" : " on " + Qt.formatDate(d, "dddd"));
    }
}
