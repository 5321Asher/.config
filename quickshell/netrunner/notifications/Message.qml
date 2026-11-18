import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"

// One message, as the game's UI opens a panel: a signal line streaks in from the edge of the screen,
// the card unfolds downwards from it and glitches into focus (shaders/glitch.frag), the sender's
// name decodes itself and the message types out under the contact's picture. A bar along the bottom
// drains until it goes (the pointer resting on it holds it); leaving, the card folds back up into
// the line and the line pulls away. Urgent (critical): PRIORITY in red with hazard stripes, a jolt
// on arrival, and it stays. Click: dismiss (running its default action).
Item {
    id: root

    required property int nid
    readonly property Notification n: Notifs.notification(nid)
    readonly property bool urgent: n?.urgency === NotificationUrgency.Critical
    readonly property color edge: urgent ? Theme.red : Theme.cyan
    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "default")

    function plain(s) {
        return (s ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }
    function resolve(i) {
        if (!i) return "";
        if (i.startsWith("/")) return "file://" + i;
        if (i.startsWith("file:")) return i;
        if (i.startsWith("image://icon/")) i = i.slice(13);
        else if (i.startsWith("image://")) return i;
        return Quickshell.hasThemeIcon(i) ? Quickshell.iconPath(i) : "";
    }
    readonly property string picture: resolve(n?.image ?? "") || resolve(n?.appIcon ?? "")
    readonly property string body: plain(n?.body)

    width: Theme.toastWidth
    height: (card.full + 8) * root.open

    // ---------------------------------------------------------------- arriving, waiting, leaving
    Driver { id: arrive; until: 720 }    // long enough for the typing (260 + at most 420)
    Driver { id: going; until: 340 }
    property bool leaving: false
    property real time: 0
    FrameAnimation { running: arrive.running || going.running || root.urgent; onTriggered: root.time += frameTime }
    Component.onCompleted: arrive.play()
    function leave(dismissed) {
        if (leaving) return;
        leaving = true;
        gone.dismissed = dismissed;
        going.play();
    }
    Connections {
        target: going
        function onRunningChanged() { if (!going.running && root.leaving) gone.start(); }
    }
    Timer {
        id: gone
        property bool dismissed: false
        interval: 1
        onTriggered: { if (root.n && dismissed) root.n.dismiss(); Notifs.drop(root.nid); }
    }
    Connections { target: root.n; function onClosed() { root.leave(false); } }
    // the countdown: drains while nothing holds it
    property real remaining: 1
    NumberAnimation on remaining {
        running: !root.urgent && !root.leaving && !hover.hovered && !arrive.running
        to: 0
        duration: Theme.toastTimeout * root.remaining
        onFinished: if (root.remaining <= 0.001) root.leave(false)
    }
    HoverHandler { id: hover }

    readonly property real a: arrive.ms
    readonly property real g: going.ms
    // the line: in from the right (arriving), away to the right (leaving)
    readonly property real lineIn: leaving ? 1 - Theme.seg(g, 180, 340) : Theme.out3(Theme.seg(a, 0, 150))
    readonly property real lineX: leaving ? Theme.seg(g, 180, 340) : 0
    // the card: unfolds down from the line, folds back up
    readonly property real open: leaving ? 1 - Theme.inOut(Theme.seg(g, 40, 220)) : Theme.out3(Theme.seg(a, 110, 330))
    readonly property real glitch: leaving ? Theme.seg(g, 0, 160) : 1 - Theme.seg(a, 160, 520)
    readonly property real jolt: urgent && arrive.running ? Math.sin(a / 14) * 9 * (1 - Theme.seg(a, 300, 560)) * Theme.seg(a, 300, 320) : 0
    readonly property int typed: Math.round(Theme.seg(a, 260, 260 + Math.min(420, body.length * 6)) * body.length)

    // the signal line
    Rectangle {
        x: root.width * (1 - root.lineIn) + root.lineX * root.width + 30 * (1 - root.lineIn)
        width: root.width * root.lineIn
        height: 2
        color: Qt.lighter(root.edge, 1.3)
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 8; color: Theme.alpha(root.edge, 0.22) }
    }

    Item {
        id: card
        readonly property real full: col.implicitHeight + 30
        y: 2
        width: root.width
        height: full * root.open
        clip: true
        transform: Translate { x: root.jolt }

        Item {
            id: face
            width: card.width
            height: card.full
            layer.enabled: root.glitch > 0.002
            layer.effect: ShaderEffect {
                fragmentShader: Qt.resolvedUrl("../shaders/glitch.frag.qsb")
                property vector2d size: Qt.vector2d(face.width, face.height)
                property real amount: root.glitch
                property real time: root.time
                property real seed: (root.nid % 97) / 97
                property color red: Theme.red
                property color cyan: Theme.cyan
            }

            Chamfer { anchors.fill: parent; cut: 12; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.95); stroke: Theme.alpha(root.edge, 0.8) }
            Hazard { visible: root.urgent; x: parent.width - 110; y: 0; width: 96; height: 6 }
            Rectangle {
                width: 2; height: parent.height - 12; color: root.edge
                opacity: root.urgent ? 0.6 + 0.4 * Math.abs(Math.sin(root.time * 3)) : 1
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    const def = (root.n?.actions ?? []).find(x => x.identifier === "default");
                    if (def) def.invoke();
                    root.leave(true);
                }
            }

            Column {
                id: col
                x: 16; y: 14
                width: parent.width - 32
                spacing: 8
                Row {
                    spacing: 8
                    Tag { height: 18; pixelSize: 10; text: root.urgent ? "PRIORITY" : "INCOMING MESSAGE"; color: root.edge }
                    Jp { anchors.verticalCenter: parent.verticalCenter; text: root.urgent ? "緊急" : "受信"; color: root.edge }
                    Row {           // the signal, while it comes in
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 3; height: 4 + index * 2
                                color: index < Math.ceil(Theme.seg(root.a, 200, 520) * 4) ? root.edge : Theme.line
                            }
                        }
                    }
                }
                Row {
                    width: parent.width
                    spacing: 12
                    // the contact: picture in brackets
                    Item {
                        width: 46; height: 46
                        visible: root.picture !== ""
                        Rectangle { anchors.fill: parent; color: Theme.alpha(root.edge, 0.08); border.width: 1; border.color: Theme.alpha(root.edge, 0.45) }
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 36
                            source: root.picture
                            opacity: root.arriving ? (Math.random() < 0.3 ? 0.3 : 1) : 1
                        }
                        Repeater {
                            model: 4
                            Item {
                                required property int index
                                x: index % 2 ? 46 - 8 : 0; y: index > 1 ? 46 - 8 : 0
                                width: 8; height: 8
                                Rectangle { x: index % 2 ? 6 : 0; width: 2; height: 8; color: root.edge }
                                Rectangle { y: index > 1 ? 6 : 0; width: 8; height: 2; color: root.edge }
                            }
                        }
                    }
                    Column {
                        width: parent.width - (root.picture ? 58 : 0)
                        spacing: 3
                        Label { text: root.n?.appName || "system"; strong: true; color: root.edge }
                        Scramble {
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            target: root.plain(root.n?.summary)
                            duration: 300
                            color: Theme.bright
                            font.family: Theme.sans
                            font.pixelSize: Theme.data + 2
                            font.weight: Font.DemiBold
                        }
                        Text {      // the whole body, unseen, holds the height so typing doesn't move anything
                            id: bodyFull
                            visible: false
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            text: root.body
                            font: bodyText.font
                        }
                        Text {
                            id: bodyText
                            visible: root.body !== ""
                            width: parent.width
                            height: bodyFull.height
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            text: root.body.slice(0, root.typed) + (root.typed < root.body.length ? "▌" : "")
                            color: Theme.fg
                            font.family: Theme.sans
                            font.pixelSize: Theme.data
                        }
                    }
                }
                Flow {
                    visible: root.actions.length > 0
                    width: parent.width
                    spacing: 6
                    Repeater { model: root.actions
                        Btn { required property var modelData; text: modelData.text || modelData.identifier; onClicked: { modelData.invoke(); root.leave(true); } } }
                }
            }
            // what's left before it goes
            Rectangle {
                visible: !root.urgent
                x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                width: (parent.width - 24) * root.remaining
                height: 2
                color: Theme.alpha(root.edge, 0.6)
            }
        }
    }
    readonly property bool arriving: arrive.running && arrive.ms < 500
}
