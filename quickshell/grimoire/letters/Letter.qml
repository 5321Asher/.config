import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"
import "../utilities"

// One notification, as a sealed letter. It slides in from the right edge, turning slightly as if
// tossed onto the desk: a folded parchment packet with the sender and the gist on its face and its
// flap closed with a wax seal stamped with the sender's initial. Rest the pointer on it and the seal
// cracks, the flap folds open and the letter unfolds to show the rest and its replies. Leaves after
// Theme.letterTimeout (never while you're reading it); urgent letters are sealed in glowing arcane
// wax and stay. Click to act on it (its default action) and put it away.
Item {
    id: root

    required property int nid
    readonly property Notification n: Notifs.notification(nid)
    readonly property bool urgent: n?.urgency === NotificationUrgency.Critical
    readonly property var actions: (n?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property string app: n?.appName || "a stranger"

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
    readonly property string bodyText: plain(n?.body)

    width: Theme.letterWidth + 30
    height: letter.height + 12

    // ---------------------------------------------------------------- arrival and leaving
    property bool leaving: false
    property real slide: 1
    Behavior on slide { NumberAnimation { duration: Theme.slow + 120; easing.type: Easing.OutCubic } }
    readonly property real tilt: ((nid * 37) % 7 - 3) * 0.35
    Component.onCompleted: slide = 0
    function leave(dismissed) {
        if (leaving) return;
        leaving = true;
        slide = 1;
        gone.dismissed = dismissed;
        gone.start();
    }
    Timer {
        id: gone
        property bool dismissed: false
        interval: Theme.slow + 140
        onTriggered: { if (root.n && dismissed) root.n.dismiss(); Notifs.drop(root.nid); }
    }
    Connections { target: root.n; function onClosed() { root.leave(false); } }
    Timer { interval: Theme.letterTimeout + (root.isOpen ? 4000 : 0); running: !root.urgent && !root.leaving && !hover.hovered; onTriggered: root.leave(false) }
    HoverHandler { id: hover; onHoveredChanged: if (hovered) root.opened = true }

    // opened once the seal is broken (it stays open: a broken seal can't be mended)
    property bool opened: false
    readonly property bool isOpen: opened || Debug.lettersOpen
    property real unfold: isOpen ? 1 : 0
    Behavior on unfold { NumberAnimation { duration: Theme.slow + 80; easing.type: Easing.InOutCubic } }

    Item {
        id: letter
        x: 24 + root.slide * (root.width + 60)
        width: Theme.letterWidth
        height: face.height + (inner.implicitHeight + 16) * root.unfold
        rotation: root.tilt + root.slide * 9
        transformOrigin: Item.Right
        opacity: 1 - root.slide * 0.6

        // shadow on the desk
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 6; anchors.leftMargin: 4; anchors.rightMargin: -4; anchors.bottomMargin: -8
            radius: 3
            color: Qt.alpha("#000000", 0.45)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.7; blurMax: 20 }
        }
        Parchment { anchors.fill: parent; age: 0.5 }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const def = (root.n?.actions ?? []).find(a => a.identifier === "default");
                if (def) def.invoke();
                root.leave(true);
            }
        }

        // ---------------------------------------------------------------- the face
        Item {
            id: face
            width: parent.width
            height: Math.max(96 - 30 * root.unfold, faceText.implicitHeight + 26)

            Column {
                id: faceText
                x: 18; y: 13
                width: parent.width - 18 - 118
                spacing: 3
                Row {
                    spacing: 6
                    IconImage { visible: root.picture !== ""; anchors.verticalCenter: parent.verticalCenter; implicitSize: 16; source: root.picture }
                    Body {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.urgent ? "an urgent sending from " : "a letter from ") + root.app
                        italic: true
                        color: root.urgent ? Theme.rubric : Theme.inkDim
                        font.pixelSize: 13
                    }
                }
                Body {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: root.plain(root.n?.summary)
                    strong: true
                    font.pixelSize: 16
                }
            }

            // the flap, folded over from the right edge, closed by the seal at its point
            Item {
                id: flapBox
                x: parent.width - 120
                width: 120
                height: face.height
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    opacity: 1 - root.unfold
                    transform: Scale { origin.x: 120; xScale: 1 - root.unfold * 0.92 }
                    ShapePath {
                        strokeColor: Theme.alpha(Theme.mix(Theme.pageDeep, Theme.ink, 0.4), 0.8)
                        strokeWidth: 1
                        fillGradient: LinearGradient {
                            x1: 120; y1: 0; x2: 30; y2: 0
                            GradientStop { position: 0; color: Theme.mix(Theme.page, Theme.pageDeep, 0.5) }
                            GradientStop { position: 1; color: Theme.mix(Theme.page, Theme.pageDeep, 0.15) }
                        }
                        startX: 120; startY: 0
                        PathLine { x: 44; y: face.height / 2 }
                        PathLine { x: 120; y: face.height }
                    }
                }
                WaxSeal {
                    x: 44 - width / 2 + root.unfold * 30
                    y: face.height / 2 - height / 2
                    wax: root.urgent ? Theme.mix(Theme.arcane, Theme.wax, 0.35) : Theme.wax
                    letter: (root.app.match(/[A-Za-z]/)?.[0] ?? "G").toUpperCase()
                    seed: root.nid * 1.7
                    broken: root.isOpen
                    glowing: root.urgent
                }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 4
                visible: root.isOpen
                text: "✕"
                color: Theme.inkDim
                font.pixelSize: 12
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.leave(true) }
            }
        }

        // ---------------------------------------------------------------- the inside
        Column {
            id: inner
            x: 18
            y: face.height
            width: parent.width - 36
            spacing: 10
            opacity: Math.max(0, root.unfold * 1.6 - 0.6)
            visible: root.unfold > 0.01
            // the fold line
            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.mix(Theme.pageDeep, Theme.ink, 0.3), 0.7) }
            Row {
                width: parent.width
                spacing: 12
                Initial {
                    visible: root.bodyText !== ""
                    letter: root.bodyText.charAt(0).toUpperCase().match(/[A-Z]/) ? root.bodyText.charAt(0).toUpperCase() : "✦"
                    size: 40
                }
                Body {
                    width: parent.width - (root.bodyText !== "" ? 52 : 0)
                    wrapMode: Text.Wrap
                    maximumLineCount: 8
                    elide: Text.ElideRight
                    text: root.bodyText.length > 1 && root.bodyText.charAt(0).match(/[A-Za-z]/) ? root.bodyText.slice(1) : (root.bodyText || "(the letter is blank)")
                    italic: root.bodyText === ""
                    font.pixelSize: 15
                    lineHeight: 1.1
                }
            }
            Flow {
                visible: root.actions.length > 0
                width: parent.width
                spacing: 8
                Repeater { model: root.actions
                    Btn { required property var modelData; text: modelData.text || modelData.identifier; onClicked: { modelData.invoke(); root.leave(true); } } }
            }
        }
    }
}
