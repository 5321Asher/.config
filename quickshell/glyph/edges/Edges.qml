import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"

// Glyph: the screen's edges as the LED strips on the back of the phone, instead of OSDs and pop-ups.
// Right: volume / brightness, lit from the bottom up, with a capsule for the number. Top: a flash on
// each notification (red for critical ones) and the island, a stack of pills that grow into cards.
// Bottom: the progress of a long task (a notification with a value hint) or of the focus timer.
// Everything is on the screen with the keyboard focus, and goes out after 3 s.
Scope {
    id: root

    readonly property var focused: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    // ---- right: volume and brightness ----
    property string kind: "vol"
    property real value: 0
    property bool armed: false          // no flash for the first values at start
    Timer { running: true; interval: 2500; onTriggered: root.armed = true }
    function level(k, v) {
        if (!armed) return;
        kind = k;
        value = v;
        side.shown = true;
        sideT.restart();
    }
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink].filter(n => n) }
    readonly property bool muted: sink?.audio?.muted ?? false
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.level("vol", root.muted ? 0 : root.sink.audio.volume); }
        function onMutedChanged() { root.level("vol", root.muted ? 0 : root.sink.audio.volume); }
    }
    Connections {
        target: Backlight
        function onValueChanged() { root.level("bri", Backlight.value); }
    }
    Connections {
        target: Brightness
        function onDisplaysChanged() { if (Brightness.displays.length) root.level("bri", Brightness.displays[0].value ?? 0); }
    }
    Timer { id: sideT; interval: 3000; onTriggered: side.shown = false }

    // ---- top: a flash per notification; cards in the island ----
    property bool flash: false
    property bool flashCrit: false
    Timer { id: flashT; interval: 3000; onTriggered: root.flash = false }
    Connections {
        target: Notifs.model
        function onRowsInserted() {
            const n = Notifs.notification(Notifs.model.get(0)?.nid);
            root.flashCrit = n?.urgency === NotificationUrgency.Critical;
            root.flash = true;
            flashT.restart();
        }
    }

    // power: plugged in, unplugged, low (15 %), critical (5 %): a card of their own, not in history
    readonly property var bat: UPower.displayDevice
    readonly property int pct: Math.round((bat?.percentage ?? 0) * 100)
    property int warned: 100
    ListModel { id: own }
    function power(summary, glyph, crit) {
        if (!root.armed || !root.bat?.isLaptopBattery) return;
        own.insert(0, { summary: summary, body: `${root.pct}%`, glyph: glyph, crit: !!crit });
        root.flashCrit = !!crit;
        root.flash = true;
        flashT.restart();
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.warned = 100;
            root.power(UPower.onBattery ? "On battery" : "Charging", UPower.onBattery ? "\u{F0079}" : "\u{F0084}", false);
        }
    }
    Connections {
        target: root.bat
        function onPercentageChanged() {
            if (!UPower.onBattery) return;
            if (root.pct <= 5 && root.warned > 5) { root.warned = 5; root.power("Battery critical · plug in now", "\u{F0083}", true); }
            else if (root.pct <= 15 && root.warned > 15) { root.warned = 15; root.power("Battery low · plug in soon", "\u{F0083}", false); }
        }
    }

    Edge {
        id: top
        shown: root.flash
        anchors.top: true
        implicitWidth: Math.ceil(640 * s)
        implicitHeight: Math.ceil(30 * s)
        Seg {
            x: 20
            y: 4
            width: 600
            height: 4
            n: 12
            f: 1
            on: root.flashCrit ? Theme.red : Theme.fg
            layer.enabled: true
            layer.effect: Glow {}
            SequentialAnimation on opacity {
                running: top.shown
                loops: Animation.Infinite
                NumberAnimation { from: 0.15; to: 1; duration: 720; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.15; duration: 1680; easing.type: Easing.InOutSine }
            }
        }
    }

    // the island: cards top centre, newest on top. Each drops as a pill, spreads into a card and its
    // text shows last; leaving, it shrinks back and its place closes up. 5 s each; hovering holds them
    PanelWindow {
        id: island
        screen: root.focused
        readonly property real s: Theme.scaleFor(screen)
        visible: Notifs.model.count > 0 || own.count > 0
        anchors.top: true
        implicitWidth: Math.ceil(600 * s)
        implicitHeight: Math.ceil((24 + 4 * 132) * s)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: col }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-island"

        Stage {
            s: island.s
            Column {
                id: col
                y: 24
                width: 600
                HoverHandler { id: hov }

                Repeater {
                    model: own
                    Card {
                        required property int index
                        required property string summary
                        required property string body
                        required property string glyph
                        required property bool crit
                        app: "power"
                        head: summary
                        text: body
                        icon: glyph
                        critical: crit
                        newest: index === 0 && Notifs.model.count === 0
                        onGone: own.remove(index)
                    }
                }
                Repeater {
                    model: Notifs.model
                    Card {
                        id: card
                        required property int index
                        required property int nid
                        readonly property var n: Notifs.notification(nid)
                        app: n?.appName || "app"
                        head: n?.summary ?? ""
                        text: (n?.body ?? "").replace(/<[^>]*>/g, "")
                        image: {
                            let i = n?.image || n?.appIcon || "";
                            if (i.startsWith("image://icon/")) i = i.slice(13);
                            if (i.startsWith("/") ) return "file://" + i;
                            if (i.startsWith("file://") || i.startsWith("image://")) return i;
                            return i ? Quickshell.iconPath(i, true) : "";
                        }
                        critical: n?.urgency === NotificationUrgency.Critical
                        newest: index === 0
                        onClicked: { n?.actions?.find(a => a.identifier === "default")?.invoke(); }
                        onGone: Notifs.drop(nid)
                    }
                }
            }
        }
    }

    component Card: Item {
        id: c
        property string app
        property string head
        property string text
        property string icon: ""
        property string image: ""
        property bool critical
        property bool newest
        property bool leaving: false
        signal clicked()
        signal gone()

        // p 0…1, each phase with its own ease-out-quart (the glide curve)
        property real p: 0
        Component.onCompleted: p = Qt.binding(() => leaving ? 0 : 1)
        Behavior on p { NumberAnimation { duration: c.leaving ? 450 : 700 } }
        onPChanged: if (leaving && p <= 0) Qt.callLater(c.gone)
        function ph(a, b) { const x = Math.max(0, Math.min(1, (p - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }
        readonly property real drop: ph(0, 0.3)
        readonly property real grow: ph(0.25, 0.8)
        readonly property real full: Math.max(86, txt.height + 32)

        width: 600
        height: (40 + (full - 40) * grow + 12) * drop
        Timer { running: !c.leaving && !hov.hovered; interval: c.critical ? 9000 : 5000; onTriggered: c.leaving = true }

        Rectangle {
            width: 140 + (600 - 140) * c.grow
            height: 40 + (c.full - 40) * c.grow
            x: (600 - width) / 2
            y: -24 * (1 - c.drop)
            opacity: c.drop
            radius: Math.min(34, height / 2)
            clip: true
            color: Theme.s1
            border { width: 1; color: c.critical ? Theme.red : Theme.fg }

            Item {
                anchors.centerIn: parent
                width: 600
                height: c.full
                opacity: c.ph(0.7, 1)

                Rectangle {
                    id: ic
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 54
                    height: 54
                    radius: 27
                    color: Theme.s2
                    Icon { anchors.centerIn: parent; visible: !img.visible; text: c.icon || "\u{F009A}"; font.pixelSize: 24 }
                    Image {
                        id: img
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        visible: status === Image.Ready
                        source: c.image
                        sourceSize: Qt.size(60, 60)
                        fillMode: Image.PreserveAspectFit
                        layer.enabled: true
                        layer.effect: Dm { step: 2 }
                    }
                }
                Column {
                    id: txt
                    anchors { left: ic.right; leftMargin: 16; right: dot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    Lb { width: parent.width; elide: Text.ElideRight; text: `${c.app} · now` }
                    Text {
                        width: parent.width
                        topPadding: 2
                        elide: Text.ElideRight
                        text: c.head
                        font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold }
                        color: Theme.fg
                    }
                    Text {
                        width: parent.width
                        visible: !!c.text
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: c.text
                        font { family: Theme.ui; pixelSize: 14 }
                        color: Theme.grey
                    }
                }
                // the red dot: only on the newest (there's one red thing on screen)
                Rectangle { id: dot; visible: c.newest; anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter } width: 12; height: 12; radius: 6; color: Theme.red }
            }

            TapHandler { onTapped: { c.clicked(); c.leaving = true; } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: c.leaving = true }
        }
    }

    // ---- right ----
    Edge {
        id: side
        anchors.right: true
        implicitWidth: Math.ceil(160 * s)
        implicitHeight: Math.ceil(520 * s)
        Lit {
            x: 160 - 5 - 5
            y: 10
            width: 5
            height: 500
            n: 20
            vertical: true
            f: root.value
        }
        Tag {
            vertical: true
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            Icon { text: root.kind === "bri" ? "\u{F00E0}" : root.muted ? "\u{F075F}" : "\u{F057E}" }
            Num { text: Math.round(root.value * 100); font.pixelSize: 30 }
        }
    }

    // ---- bottom: a task's progress, else a running focus timer (a strip, no capsule) ----
    readonly property var task: Notifs.history.find(n => n.hints?.value !== undefined) ?? null
    readonly property real progress: task ? Math.max(0, Math.min(100, task.hints.value ?? 0)) / 100 : FocusTimer.progress
    Edge {
        shown: !!root.task || FocusTimer.running
        anchors.bottom: true
        implicitWidth: Math.ceil(1100 * s)
        implicitHeight: Math.ceil(110 * s)
        Lit {
            x: 10
            y: 110 - 5 - 5
            width: 1080
            height: 5
            n: 40
            f: root.progress
        }
        Tag {
            visible: !!root.task
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            Icon { text: "\u{F01DA}" }
            Lb { text: root.task?.summary ?? ""; color: Theme.fg }
            Num { text: Math.round(root.progress * 100) + "%"; font.pixelSize: 26 }
        }
    }

    // a strip at an edge: no input, drawn in design pixels, on the focused screen
    component Edge: PanelWindow {
        id: e
        property bool shown
        default property alias content: st.data
        readonly property real s: Theme.scaleFor(screen)
        screen: root.focused
        visible: shown
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-edge"
        Stage { id: st; s: e.s }
    }
    // the capsule with the value beside a strip; vertical = stacked
    component Tag: Rectangle {
        default property alias content: box.data
        property bool vertical
        width: vertical ? Math.max(52, box.width + 24) : box.width + 32
        height: vertical ? box.height + 36 : 52
        radius: Math.min(width, height) / 2
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
        Grid {
            id: box
            anchors.centerIn: parent
            columns: parent.vertical ? 1 : 99
            spacing: parent.vertical ? 10 : 12
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
        }
    }
    // the lit segments' glow: the only "shadow" in the whole shell
    component Glow: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.glow
        shadowBlur: 0.7
        blurMax: 20
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
