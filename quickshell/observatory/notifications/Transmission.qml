import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../theme"
import "../services"

// One incoming transmission: slides in from the right, types its text out character by character
// behind a faint scanline overlay, and leaves after Theme.transmissionTimeout (hover holds it;
// critical ones stay until clicked). Click anywhere to dismiss.
Item {
    id: root

    required property int nid
    required property double born
    readonly property Notification n: Transmissions.notification(nid)

    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    readonly property color edge: critical ? Theme.signal : Theme.brass
    readonly property string summary: plain(n?.summary ?? "")
    readonly property string body: plain(n?.body ?? "")
    readonly property int total: summary.length + body.length

    function plain(s) {
        return s.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
                .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
                .replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }

    width: Theme.transmissionWidth
    height: card.height

    // ---------------------------------------------------------------- arrive / leave
    property bool leaving: false
    property real slide: 1          // 1 = off to the right, 0 = in place
    Behavior on slide { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }
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
        interval: Theme.slow
        onTriggered: {
            if (root.n) { if (dismissed) root.n.dismiss(); else root.n.expire(); }
            Transmissions.drop(root.nid);
        }
    }
    Connections {
        target: root.n
        function onClosed() { if (!root.leaving) { root.leaving = true; root.slide = 1; dropLater.start(); } }
    }
    Timer { id: dropLater; interval: Theme.slow; onTriggered: Transmissions.drop(root.nid) }

    // ---------------------------------------------------------------- the countdown
    property real remaining: 1
    NumberAnimation on remaining {
        id: countdown
        from: 1
        to: 0
        duration: Theme.transmissionTimeout
        running: !root.critical && !root.leaving
        paused: running && hover.hovered
        onFinished: root.leave(false)
    }

    // ---------------------------------------------------------------- typing
    property int typed: 0
    Timer {
        interval: Theme.typeInterval
        repeat: true
        running: root.typed < root.total && root.slide < 0.6
        onTriggered: root.typed = Math.min(root.total, root.typed + Theme.typeChars)
    }
    property bool cursorOn: true
    Timer {
        interval: 420
        repeat: true
        running: true
        onTriggered: root.cursorOn = !root.cursorOn
    }

    // ---------------------------------------------------------------- card
    Item {
        id: card
        x: root.slide * (root.width + 40)
        opacity: 1 - root.slide * 0.8
        width: root.width
        height: content.implicitHeight + 2 * Theme.transmissionPad

        // Plate: translucent, brass hairline, the top-left corner cut like a machined tag
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1
                strokeColor: Theme.alpha(root.edge, 0.75)
                fillColor: Theme.panel
                startX: Theme.chamfer; startY: 0.5
                PathLine { x: card.width - 0.5; y: 0.5 }
                PathLine { x: card.width - 0.5; y: card.height - 0.5 }
                PathLine { x: 0.5; y: card.height - 0.5 }
                PathLine { x: 0.5; y: Theme.chamfer }
                PathLine { x: Theme.chamfer; y: 0.5 }
            }
        }

        // Scanlines, drawn once, and a slow bright sweep
        Canvas {
            anchors.fill: parent
            anchors.margins: 1
            opacity: Theme.scanlineOpacity
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.phosphor;
                for (let y = 0; y < height; y += Theme.scanlineSpacing) ctx.fillRect(0, y, width, 1);
            }
            onHeightChanged: requestPaint()
        }
        Rectangle {
            id: sweep
            x: 1
            width: parent.width - 2
            height: 18
            opacity: 0.06
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.8; color: Theme.phosphor }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on y {
                from: -18
                to: card.height
                duration: 2600
                loops: Animation.Infinite
            }
        }

        Column {
            id: content
            x: Theme.transmissionPad
            y: Theme.transmissionPad
            width: parent.width - 2 * Theme.transmissionPad
            spacing: 5

            // Header: receive light, "incoming transmission · app", time
            Item {
                width: parent.width
                height: header.implicitHeight

                Rectangle {
                    id: light
                    anchors.verticalCenter: header.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: root.critical ? Theme.signal : Theme.phosphor
                    opacity: root.typed < root.total ? (root.cursorOn ? 1 : 0.25) : 0.8
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                Text {
                    id: header
                    anchors.left: light.right
                    anchors.leftMargin: 7
                    anchors.right: time.left
                    anchors.rightMargin: 8
                    elide: Text.ElideRight
                    text: (root.critical ? "priority transmission" : "incoming transmission")
                          + ((root.n?.appName ?? "") !== "" ? "  ·  " + root.n.appName.toLowerCase() : "")
                    color: root.edge
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize - 1
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                }
                Text {
                    id: time
                    anchors.right: parent.right
                    anchors.verticalCenter: header.verticalCenter
                    text: Qt.formatDateTime(new Date(root.born), "HH:mm:ss")
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }

            // Hairline under the header
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.alpha(root.edge, 0.25)
            }

            Row {
                width: parent.width
                spacing: 10

                // Sender's image or app icon, in a brass ring
                Item {
                    id: iconBox
                    // image hint first, then the app icon; theme icon names only if the theme has them
                    function resolve(i) {
                        if (!i) return "";
                        if (i.startsWith("/") || i.startsWith("file:")) return i;
                        if (i.startsWith("image://icon/")) i = i.slice(13);
                        else if (i.startsWith("image://")) return i;
                        return Quickshell.hasThemeIcon(i) ? Quickshell.iconPath(i) : "";
                    }
                    readonly property string src: resolve(root.n?.image ?? "") || resolve(root.n?.appIcon ?? "")
                    visible: src !== ""
                    width: visible ? Theme.transmissionIcon : 0
                    height: Theme.transmissionIcon

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.bgDark
                        IconImage {
                            anchors.fill: parent
                            anchors.margins: iconBox.src.startsWith("image://") && !iconBox.src.startsWith("image://icon/") ? 0 : 5
                            source: iconBox.src
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.alpha(root.edge, 0.8)
                    }
                }

                Column {
                    width: parent.width - (iconBox.visible ? iconBox.width + parent.spacing : 0)
                    spacing: 3

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: root.summary.slice(0, root.typed)
                              + (root.typed < root.summary.length && root.cursorOn ? "▌" : "")
                        color: Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        visible: root.body !== ""
                        wrapMode: Text.Wrap
                        maximumLineCount: Theme.transmissionLines
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: root.body.slice(0, Math.max(0, root.typed - root.summary.length))
                              + (root.typed >= root.summary.length && root.cursorOn ? "▌" : "")
                        color: Theme.phosphor
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall + 1
                        lineHeight: 1.1
                    }
                }
            }

            // Actions, as small-caps brass links
            Row {
                visible: (root.n?.actions?.length ?? 0) > 0
                spacing: 16
                Repeater {
                    model: root.n?.actions ?? []
                    Text {
                        required property var modelData
                        text: modelData.text.toLowerCase()
                        color: actMouse.containsMouse ? Theme.brassBright : Theme.brass
                        font.family: Theme.fontLabel
                        font.pixelSize: Theme.labelSize
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: Theme.labelSpacing
                        font.weight: Font.DemiBold
                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { modelData.invoke(); root.leave(true); }
                        }
                    }
                }
            }
        }

        // Time left: a brass line draining from the right
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            x: 1
            height: 1.5
            width: (parent.width - 2) * (root.critical ? 1 : root.remaining)
            color: root.edge
            opacity: 0.8
        }

        HoverHandler { id: hover }
        TapHandler {
            onTapped: root.leave(true)
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.5
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            blurMax: 24
        }
    }
}
