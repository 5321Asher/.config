import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../theme"

// A holocall: how Netrunner asks you something (INPUT REQUIRED, ROOT ACCESS). call() rings: the
// caller ID flickers where the call will open; then a projector line opens across the top and the
// panel builds itself downwards behind a bright scan front, jittering and split red / cyan until the
// signal locks. The caller speaks: `line`, typed out like the game's subtitles, while the voice bars
// under the portrait move. Children are the answer (a reply line, dialogue choices, a passphrase);
// appear(i) staggers them in. hangUp() collapses the call to a line and then a dot, like a CRT
// switching off; drop() loses the signal in static; deny() bursts red static and shakes, and the call
// stays open. `busy` holds until the exit has played (keep the window up while it is true).
Item {
    id: root

    property string caller: "UNKNOWN CALLER"
    property string avatar: "dialog-question"
    property string line: ""
    property color tint: Theme.cyan
    property string tag: "HOLOCALL"
    property string jp: "通話"
    property string status: "LINKED"
    property string hints: ""                // key hints along the bottom
    default property alias body: slot.data

    property string phase: "idle"           // idle | intro | live | hangup | drop
    readonly property bool busy: phase !== "idle"
    readonly property bool talking: typer.running
    signal ended()

    implicitHeight: Math.max(nameplate.y + nameplate.height, talk.y + slot.y + slot.childrenRect.height + (hints ? 34 : 0)) + 22

    function call() {
        phase = "intro";
        clock.until = 1250;
        clock.play();
        typer.stop();
        typer.ms = 0;
        began = Date.now();
    }
    function hangUp() {
        if (phase !== "intro" && phase !== "live") return;
        phase = "hangup";
        clock.until = 400;
        clock.play();
    }
    function drop() {
        if (phase !== "intro" && phase !== "live") return;
        phase = "drop";
        clock.until = 440;
        clock.play();
    }
    function deny() { if (phase === "intro" || phase === "live") denied.play(); }
    // how far the i-th answer element has arrived, 0..1 (they come in one after another)
    function appear(i) { return phase === "intro" ? Theme.out3(Theme.seg(t, 760 + i * 45, 960 + i * 45)) : 1; }

    // ---------------------------------------------------------------- the clocks
    readonly property real t: clock.ms
    property real time: 0
    property double began: 0
    property int seconds: 0
    Driver {
        id: clock
        onMsChanged: if (root.phase === "intro" && ms >= 620 && !typer.running && typer.ms === 0) typer.play()
        onRunningChanged: {
            if (running) return;
            if (root.phase === "intro") root.phase = "live";
            else if (root.phase === "hangup" || root.phase === "drop") { root.phase = "idle"; root.ended(); }
        }
    }
    Driver {           // the subtitle typing out
        id: typer
        until: Math.min(650, Math.max(220, root.line.length * 14))
    }
    Driver { id: denied; until: 460 }
    FrameAnimation {
        running: root.busy
        onTriggered: {
            root.time += frameTime;
            root.seconds = Math.floor((Date.now() - root.began) / 1000);
        }
    }
    onLineChanged: if (phase === "live") typer.play()

    // ---------------------------------------------------------------- what the phases draw
    readonly property real ring: phase === "intro" ? 1 - Theme.seg(t, 380, 480) : 0
    readonly property real beam: phase === "intro" ? Theme.out3(Theme.seg(t, 340, 470)) : 1
    readonly property real build: phase === "intro" ? Theme.seg(t, 440, 840) : 1
    readonly property real settle: phase === "intro" ? Theme.out3(Theme.seg(t, 500, 1200)) : 1
    readonly property real deniedLeft: denied.running ? 1 - Theme.seg(denied.ms, 0, 460) : 0
    readonly property real staticAmt: phase === "drop" ? Theme.seg(t, 0, 200) : deniedLeft * 0.65
    readonly property real flash: phase === "hangup" ? Theme.seg(t, 0, 110) * (1 - Theme.seg(t, 250, 400)) : 0
    readonly property real sy: phase === "hangup" ? 1 - 0.99 * Theme.out3(Theme.seg(t, 0, 130)) : 1
    readonly property real sx: phase === "hangup" ? 1 - 0.996 * Theme.inOut(Theme.seg(t, 120, 270)) : 1
    readonly property real fade: phase === "hangup" ? 1 - Theme.seg(t, 280, 400) : phase === "drop" ? 1 - Theme.seg(t, 220, 440) : 1
    readonly property real shake: Math.sin(denied.ms / 16) * 8 * deniedLeft
    // how present the call is, for the window's dimming: 0..1
    readonly property real presence: phase === "intro" ? Theme.seg(t, 0, 380) : phase === "idle" ? 0 : fade

    readonly property string typed: line.slice(0, Math.round(Theme.seg(typer.ms, 0, typer.until) * line.length))
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

    // ---------------------------------------------------------------- ringing
    Row {
        id: ringing
        visible: root.ring > 0
        opacity: root.ring * (0.75 + 0.25 * Math.round(Math.sin(root.time * 40) * 0.5 + 0.5))
        spacing: 12
        Item {
            width: 34; height: 34
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real k: ((root.t + index * 120) % 360) / 360
                    anchors.centerIn: parent
                    width: 10 + k * 34; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.alpha(root.tint, 1 - k)
                }
            }
            Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: root.tint }
        }
        Tag { anchors.verticalCenter: parent.verticalCenter; text: "INCOMING CALL"; height: 22; color: root.tint }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.caller
            color: Theme.bright
            font.family: Theme.display; font.pixelSize: 18; font.weight: Font.Bold; font.letterSpacing: 1
        }
    }

    // the projector line opening across the top, before the panel builds under it
    Rectangle {
        visible: root.phase === "intro" && root.t > 340 && root.t < 520
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width * root.beam
        height: 2
        color: Qt.lighter(root.tint, 1.4)
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 8; color: Theme.alpha(root.tint, 0.25) }
    }

    // ---------------------------------------------------------------- the call
    Item {
        id: surface
        width: root.width
        height: root.height
        visible: root.phase !== "intro" || root.t > 440
        opacity: root.fade
        transform: [
            Scale { origin.x: surface.width / 2; origin.y: surface.height / 2; xScale: root.sx; yScale: root.sy },
            Translate { x: root.shake; y: root.phase === "drop" ? Theme.seg(root.t, 200, 440) * 14 : 0 }
        ]
        layer.enabled: true
        layer.smooth: true
        layer.effect: ShaderEffect {
            fragmentShader: Qt.resolvedUrl("../shaders/holo.frag.qsb")
            property vector2d size: Qt.vector2d(surface.width, surface.height)
            property real build: root.build
            property real settle: root.settle
            property real staticAmt: root.staticAmt
            property real flash: root.flash
            property real time: root.time
            property color tint: root.deniedLeft > 0 ? Theme.red : root.tint
        }

        Chamfer {
            anchors.fill: parent
            cut: 18
            corners: "tl br"
            fill: Theme.alpha(Theme.bgDark, 0.95)
            stroke: Theme.alpha(root.deniedLeft > 0.3 ? Theme.red : root.tint, 0.7)
        }
        Hazard { x: parent.width - 120; y: parent.height - 6; width: 90; height: 6 }

        // the caller: a portrait in the projector's light, the voice moving under it
        Item {
            id: portrait
            x: 22; y: 22
            width: 156; height: 176
            Chamfer { anchors.fill: parent; cut: 12; corners: "tl br"; fill: Theme.alpha(root.tint, 0.06); stroke: Theme.alpha(root.tint, 0.45) }
            Rectangle {
                anchors.fill: parent; anchors.margins: 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.alpha(root.tint, 0.2) }
                }
            }
            IconImage {
                id: face
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                y: 22
                implicitSize: 92
                source: Quickshell.iconPath(root.avatar, "dialog-question")
            }
            MultiEffect {
                source: face
                anchors.fill: face
                colorization: 0.6
                colorizationColor: root.tint
                brightness: 0.08
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 136
                height: 24
                spacing: 3
                Repeater {
                    model: 14
                    Rectangle {
                        required property int index
                        readonly property real v: Math.abs(Math.sin(root.time * 13 + index * 1.7) * Math.sin(root.time * 7.3 + index * 0.6))
                        anchors.bottom: parent.bottom
                        width: 4
                        height: 2 + v * (root.talking ? 20 : 3)
                        color: Theme.alpha(root.tint, root.talking ? 0.9 : 0.45)
                    }
                }
            }
        }
        Column {
            id: nameplate
            x: portrait.x
            y: portrait.y + portrait.height + 10
            width: portrait.width
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.caller
                color: Theme.bright
                font.family: Theme.display; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 0.5
            }
            Row {
                spacing: 6
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 3; height: 4 + index * 2
                            color: index < (root.phase === "intro" ? Math.floor(root.settle * 4) : 4) ? root.tint : Theme.line
                        }
                    }
                }
                Label { text: "HOLO // " + root.status; color: root.tint }
            }
        }

        // the call: header, the subtitle, then the answer
        Item {
            id: talk
            x: portrait.x + portrait.width + 24
            y: 22
            width: parent.width - x - 24
            height: parent.height - y

            Row {
                id: header
                spacing: 10
                Tag { anchors.verticalCenter: parent.verticalCenter; text: root.tag; height: 22; color: root.tint }
                Jp { anchors.verticalCenter: parent.verticalCenter; text: root.jp; color: root.tint }
            }
            Label {
                anchors.right: parent.right
                anchors.verticalCenter: header.verticalCenter
                text: "● " + String(Math.floor(root.seconds / 60)).padStart(2, "0") + ":" + String(root.seconds % 60).padStart(2, "0")
                color: root.phase === "live" ? Theme.red : Theme.dim
            }
            // the full line, unseen, sizes the subtitle so nothing moves while it types out
            Text {
                id: fullLine
                visible: false
                width: talk.width
                wrapMode: Text.Wrap
                maximumLineCount: 4
                textFormat: Text.StyledText
                text: "<b>" + root.esc(root.caller) + ":</b> " + root.esc(root.line)
                font: subtitle.font
                lineHeight: subtitle.lineHeight
            }
            Text {
                id: subtitle
                y: header.height + 14
                width: talk.width
                height: fullLine.height
                wrapMode: Text.Wrap
                maximumLineCount: 4
                textFormat: Text.StyledText
                text: "<font color=\"" + root.tint + "\"><b>" + root.esc(root.caller) + ":</b></font> " + root.esc(root.typed)
                      + (root.talking ? "<font color=\"" + root.tint + "\">▌</font>" : "")
                color: Theme.bright
                font.family: Theme.condensed; font.pixelSize: 24; font.weight: Font.DemiBold; font.letterSpacing: 0.5
                lineHeight: 1.05
            }
            Label {
                anchors.right: parent.right
                y: Math.max(slot.y + slot.height + 14, nameplate.y + nameplate.height - 16 - talk.y)
                text: root.hints
            }
            Item {
                id: slot
                y: subtitle.y + subtitle.height + 16
                width: talk.width
                height: childrenRect.height
            }
        }
    }
}
