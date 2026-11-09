import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"

// The deck: a dashboard that rises from the bottom edge (Deck in the index, the rail's clock with the
// middle button, `qs ipc call dash toggle`). One long tile in sections, dotted rules between them:
// the clock and the day's progress, the weather and the next days, the gauges (CPU, memory, GPU),
// the cores, the network, now playing. Esc or a click outside puts it away. State: DeckState.
PanelWindow {
    id: root

    Binding on screen {
        when: !root.visible
        value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        restoreMode: Binding.RestoreNone
    }
    readonly property real s: Theme.scaleFor(screen)

    property real t: DeckState.open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t + 100; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: DeckState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-deck"

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var en: Qt.locale("en_US")
    readonly property var d: SysStats.data
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    property real pos: 0
    Timer { running: root.visible && !!root.player; interval: 1000; repeat: true; triggeredOnStart: true; onTriggered: root.pos = root.player?.position ?? 0 }
    Connections {
        target: DeckState
        function onOpenChanged() { if (DeckState.open) { Weather.refreshIfStale(); keys.forceActiveFocus(); } }
    }
    function week(dt) {
        const t = new Date(Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    function mmss(us) { const s = Math.floor(us); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; }
    function rate(b) { return b >= 1048576 ? [(b / 1048576).toFixed(1), "MB/S"] : [Math.round(b / 1024), "KB/S"]; }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.3 * root.t
        MouseArea { anchors.fill: parent; onClicked: DeckState.open = false }
    }
    FocusScope {
        id: keys
        focus: true
        Keys.onEscapePressed: DeckState.open = false
    }

    Stage {
        id: stage
        s: root.s

        Rectangle {
            id: panel
            readonly property bool fit: stage.width >= 1500
            width: Math.min(stage.width - 2 * (Theme.railWidth + 30), 1370)
            height: 296
            x: Theme.railWidth + (stage.width - Theme.railWidth - width) / 2
            y: stage.height - 14 - height * root.t
            radius: 40
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            MouseArea { anchors.fill: parent }

            Row {
                id: secs
                x: 28
                y: 28
                height: parent.height - 56
                spacing: 0

                // the clock
                Sec {
                    w: 240
                    Lb { text: root.en.toString(clock.date, "dddd") }
                    Row {
                        topPadding: 12
                        Num { text: Qt.formatTime(clock.date, "HH"); font.pixelSize: 64 }
                        Num { text: ":"; font.pixelSize: 64; opacity: clock.date.getSeconds() % 2 ? 0.25 : 1 }
                        Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 64 }
                    }
                    Lb { topPadding: 16; text: `${root.en.toString(clock.date, "d MMMM")} · week ${root.week(clock.date)}` }
                    Item { width: 1; height: 26 }
                    // the day so far, a dot per 40 minutes
                    Seg { width: 224; height: 5; n: 36; f: (clock.date.getHours() * 60 + clock.date.getMinutes()) / 1440 }
                    Item {
                        width: 224
                        height: 30
                        Row { y: 12; spacing: 8; Icon { text: "\u{F059C}"; font.pixelSize: 14; color: Theme.grey } Lb { text: Weather.ready ? Qt.formatTime(Weather.sunrise, "HH:mm") : "--:--" } }
                        Row { y: 12; anchors.right: parent.right; spacing: 8; Icon { text: "\u{F059B}"; font.pixelSize: 14; color: Theme.grey } Lb { text: Weather.ready ? Qt.formatTime(Weather.sunset, "HH:mm") : "--:--" } }
                    }
                }

                // the weather
                Sec {
                    w: 230
                    Lb { text: Weather.ready ? Weather.describe(Weather.current.code) : "no sky" }
                    Row {
                        topPadding: 12
                        spacing: 12
                        Icon { anchors.verticalCenter: parent.verticalCenter; text: Weather.icon(Weather.current?.code ?? 3, Weather.current?.isDay ?? true); font.pixelSize: 48; layer.enabled: true; layer.effect: Dm { step: 3 } }
                        Num { anchors.verticalCenter: parent.verticalCenter; text: Weather.ready ? Math.round(Weather.current.temp) + "°" : "--"; font.pixelSize: 56 }
                    }
                    Lb { topPadding: 14; text: Weather.ready ? `feels ${Math.round(Weather.current.feels)}° · ${Weather.windLabel}` : "" }
                    Item { width: 1; height: 22 }
                    Row {
                        spacing: 14
                        Repeater {
                            model: (Weather.daily ?? []).slice(1, 5)
                            Column {
                                required property var modelData
                                spacing: 6
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: root.en.toString(modelData.date, "ddd"); px: 10 }
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.icon(modelData.code, true); font.pixelSize: 22; layer.enabled: true; layer.effect: Dm { step: 2 } }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.max) + "°"; px: 11; color: Theme.fg }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.min) + "°"; px: 10 }
                            }
                        }
                    }
                }

                // the gauges and the cores
                Sec {
                    w: panel.fit ? 360 : 320
                    Row {
                        spacing: 22
                        Gauge { f: SysInfo.cpu; value: Math.round(SysInfo.cpu * 100); label: `cpu · ${Math.round(SysInfo.temp)}°` }
                        Gauge { f: SysInfo.mem; value: Math.round(SysInfo.mem * 100); label: root.d ? `mem · ${(root.d.mem.used / 1073741824).toFixed(1)}g` : "mem" }
                        Gauge {
                            visible: !!root.d?.gpu
                            f: (root.d?.gpu?.usage ?? 0) / 100
                            value: Math.round(root.d?.gpu?.usage ?? 0)
                            label: `gpu · ${Math.round(root.d?.gpu?.temp ?? 0)}°`
                        }
                        Gauge {
                            visible: !root.d?.gpu
                            readonly property var disk: root.d?.disks?.[0]
                            f: disk ? disk.used / disk.size : 0
                            value: Math.round(f * 100)
                            label: "disk"
                        }
                    }
                    Item { width: 1; height: 18 }
                    Lb { text: root.d ? `cores · ${(root.d.cpu.freq ?? 0).toFixed(1)} ghz · load ${(root.d.cpu.load?.[0] ?? 0).toFixed(2)}` : "cores" }
                    Item { width: 1; height: 10 }
                    // a column of dots per thread, lit from the bottom
                    Row {
                        spacing: 6
                        Repeater {
                            model: root.d?.cpu?.threads ?? []
                            Column {
                                required property real modelData
                                spacing: 3
                                Repeater {
                                    model: 6
                                    Rectangle {
                                        required property int index
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        readonly property int lit: Math.round(parent.modelData / 100 * 6)
                                        color: 6 - index <= lit ? (6 - index === lit ? Theme.fg : Theme.grey) : Theme.s3
                                    }
                                }
                            }
                        }
                    }
                }

                // the network
                Sec {
                    w: 200
                    Lb { text: `net · ${root.d?.net?.iface ?? "--"}` }
                    Row {
                        topPadding: 14
                        spacing: 10
                        Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F0045}"; font.pixelSize: 16 }
                        Num { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.rx ?? 0)[0]; font.pixelSize: 44 }
                        Lb { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.rx ?? 0)[1]; px: 10 }
                    }
                    Row {
                        topPadding: 10
                        spacing: 10
                        Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F005D}"; font.pixelSize: 16 }
                        Num { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.tx ?? 0)[0]; font.pixelSize: 44 }
                        Lb { anchors.verticalCenter: parent.verticalCenter; text: root.rate(root.d?.net?.tx ?? 0)[1]; px: 10 }
                    }
                    Item { width: 1; height: 16 }
                    Spark { width: 176; height: 48; values: SysStats.rxHistory; points: 24; rows: 6 }
                }

                // now playing
                Sec {
                    w: Math.max(200, panel.width - 56 - 240 - 230 - (panel.fit ? 360 : 320) - 200)
                    last: true
                    Lb { width: parent.width; elide: Text.ElideRight; text: root.player?.identity ?? "silence" }
                    Row {
                        topPadding: 14
                        spacing: 16
                        Item {
                            width: 84
                            height: 84
                            property real turn: 0
                            Timer { running: root.visible && !!root.player?.isPlaying; interval: 33; repeat: true; onTriggered: parent.turn = (parent.turn + 360 / 14 / 30) % 360 }
                            Art { anchors.fill: parent; rotation: parent.turn; url: root.player?.trackArtUrl ?? ""; step: 4 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(80, parent.parent.width - 100)
                            Text { width: parent.width; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; text: root.player?.trackTitle || "Nothing on"; font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold } color: Theme.fg }
                            Text { width: parent.width; elide: Text.ElideRight; text: root.player?.trackArtist ?? ""; font { family: Theme.ui; pixelSize: 13 } color: Theme.grey }
                        }
                    }
                    Item { width: 1; height: 14 }
                    Seg { width: parent.width; height: 5; n: 20; f: root.player?.lengthSupported && root.player.length > 0 ? root.pos / root.player.length : 0 }
                    Item {
                        width: parent.width
                        height: 22
                        Lb { y: 8; text: root.mmss(root.pos); px: 10 }
                        Lb { y: 8; anchors.right: parent.right; text: root.player?.lengthSupported ? root.mmss(root.player.length) : ""; px: 10 }
                    }
                    Controls { anchors.horizontalCenter: parent.horizontalCenter; player: root.player; size: 18; play: 42 }
                }
            }
        }
    }

    // a section: content in a column, a dotted rule after it
    component Sec: Item {
        id: sec
        property real w: 200
        property bool last: false
        default property alias content: c.data
        width: w + (last ? 0 : 56)
        height: secs.height
        Column { id: c; width: sec.w; clip: false }
        Column {
            visible: !sec.last
            x: sec.w + 27
            spacing: 6
            Repeater { model: Math.floor(secs.height / 9); Rectangle { width: 2; height: 2; radius: 1; color: Theme.s3 } }
        }
    }
    component Gauge: Item {
        id: g
        property real f
        property string value
        property string label
        width: 92
        height: 118
        Ring { width: 92; height: 92; n: 28; dot: 4; f: g.f; on: g.f > 0.9 ? Theme.red : Theme.fg }
        Num { anchors.centerIn: parent; anchors.verticalCenterOffset: -13; text: g.value; font.pixelSize: 30 }
        Lb { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom } text: g.label; px: 9 }
    }
}
