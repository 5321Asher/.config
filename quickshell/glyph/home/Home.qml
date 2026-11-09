import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../prefs"

// The home screen, on the bottom layer over the wallpaper (the dot grid and the halftone orb are the
// wallpaper: setups/glyph/wallpapers.py): the clock in Doto, the date, a greeting and the bento of
// widgets (weather, the month, a ring gauge, now playing, the system). Windows simply cover it.
// It only polls and animates while this screen's workspace is empty.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property real s: Theme.scaleFor(screen)

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "glyph-home"
    mask: Region { item: stage.interactive }

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool home: (monitor?.activeWorkspace?.toplevels.values.length ?? 1) === 0
    onHomeChanged: HomeState.set(screen?.name ?? "", home)
    Component.onCompleted: { HomeState.set(screen?.name ?? "", home); Weather.refreshIfStale(); }
    Component.onDestruction: HomeState.set(screen?.name ?? "", false)

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var en: Qt.locale("en_US")
    readonly property bool dim: root.home && clock.date.getMilliseconds() >= 0 && clock.date.getSeconds() % 2 === 1

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    property real pos: 0
    Timer { running: root.home && !!root.player?.isPlaying; interval: 1000; repeat: true; triggeredOnStart: true; onTriggered: root.pos = root.player?.position ?? 0 }

    readonly property var d: SysStats.data
    readonly property bool gpu: !!d?.gpu

    function week(dt) {
        const t = new Date(Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    readonly property string hello: { const h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"; }

    Stage {
        id: stage
        s: root.s
        // narrow (portrait) screens: the bento goes under the clock
        readonly property bool tall: width < 1700
        readonly property real big: tall ? Math.min(300, (width - 200) / 3.4) : 300
        property Item interactive: bento

        Row {
            id: time
            x: stage.tall ? 120 : 182
            y: 150
            Num { text: Qt.formatTime(clock.date, "HH"); font.pixelSize: stage.big }
            Num { text: ":"; font.pixelSize: stage.big; opacity: root.dim ? 0.2 : 1 }
            Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: stage.big }
        }
        Lb {
            id: date
            x: time.x + 8
            y: time.y + stage.big * 0.99
            text: `${root.en.toString(clock.date, "dddd · d MMMM")} · week ${root.week(clock.date)}`
            px: 14
        }
        Text {
            id: hi
            x: time.x + 6
            y: date.y + 110
            textFormat: Text.StyledText
            text: `${root.hello},<br><font color="${Theme.grey}">${Quickshell.env("USER")}.</font>`
            font { family: Theme.ui; pixelSize: 54; weight: Font.Light; letterSpacing: -1 }
            lineHeight: 1.1
            color: Theme.fg
        }
        Row {
            x: time.x + 8
            y: hi.y + hi.height + 18
            spacing: 28
            Meta { icon: Notifs.dnd ? "\u{F009B}" : "\u{F009A}"; text: `${Notifs.history.length} notification${Notifs.history.length === 1 ? "" : "s"}` }
            Meta { visible: Weather.ready; icon: Weather.icon(Weather.current?.code ?? 0, Weather.current?.isDay ?? true); text: `${Math.round(Weather.current?.temp ?? 0)}° ${Weather.describe(Weather.current?.code ?? 0)}` }
            Meta { visible: StayAwake.on; icon: "\u{F0176}"; text: "staying awake" }
        }

        // the bento: 220 cells, 20 apart, three columns; a square with radius 40 or a circle
        Item {
            id: bento
            x: stage.tall ? 120 : 1140
            y: stage.tall ? hi.y + 260 : 150
            width: 3 * 220 + 2 * 20
            height: 3 * 220 + 2 * 20

            // weather
            W {
                round: true
                Column {
                    anchors.centerIn: parent
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.icon(Weather.current?.code ?? 3, Weather.current?.isDay ?? true)
                        font.pixelSize: 78
                        layer.enabled: true
                        layer.effect: Dm { step: 4 }
                    }
                    Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 6; text: Weather.ready ? Math.round(Weather.current.temp) + "°" : "--"; font.pixelSize: 66 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 8
                        width: Math.min(implicitWidth, 160)
                        elide: Text.ElideRight
                        text: Weather.ready ? `${Weather.describe(Weather.current.code)} · ${Math.round(Weather.daily[0]?.min ?? 0)}°/${Math.round(Weather.daily[0]?.max ?? 0)}°` : "no sky"
                    }
                }
                TapHandler { onTapped: PrefsState.show("almanac") }
            }

            // the month
            W {
                x: 240
                Column {
                    x: 24
                    y: 24
                    width: parent.width - 48
                    Lb { text: root.en.monthName(clock.date.getMonth()) }
                    Num { topPadding: lead + 8; text: clock.date.getDate(); font.pixelSize: 118 }
                    Row {
                        width: parent.width
                        topPadding: 14
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                required property string modelData
                                required property int index
                                readonly property bool today: (clock.date.getDay() + 6) % 7 === index
                                width: parent.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font { family: Theme.mono; pixelSize: 11 }
                                color: today ? Theme.fg : Theme.grey
                                Rectangle { visible: parent.today; anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } width: 10; height: 2; color: Theme.fg }
                            }
                        }
                    }
                }
                TapHandler { onTapped: PrefsState.show("almanac") }
            }

            // a ring gauge: the GPU when there is one, else the CPU (with its temperature)
            W {
                x: 480
                round: true
                readonly property real f: root.gpu ? (root.d.gpu.usage ?? 0) / 100 : SysInfo.cpu
                Ring { anchors { fill: parent; margins: 12 } f: parent.f; on: parent.f > 0.9 ? Theme.red : Theme.fg }
                Column {
                    anchors.centerIn: parent
                    Num { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(parent.parent.f * 100); font.pixelSize: 72 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 8
                        text: root.gpu ? `gpu · ${Math.round(root.d.gpu.temp ?? 0)}°` : `cpu · ${Math.round(SysInfo.temp)}°`
                    }
                }
                TapHandler { onTapped: PrefsState.show("telemetry") }
            }

            // now playing: the art in dots turns while it plays
            W {
                y: 240
                span: 2
                Item {
                    id: art
                    x: 28
                    anchors.verticalCenter: parent.verticalCenter
                    width: 164
                    height: 164
                    property real turn: 0
                    Timer { running: root.home && !!root.player?.isPlaying; interval: 33; repeat: true; onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360 }
                    Art { anchors.fill: parent; rotation: art.turn; url: root.player?.trackArtUrl ?? ""; step: 6 }
                }
                Column {
                    anchors { left: art.right; leftMargin: 26; right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                    Lb { text: `now playing · ${root.player?.identity ?? "silence"}`; width: parent.width; elide: Text.ElideRight }
                    Text {
                        width: parent.width
                        topPadding: 10
                        elide: Text.ElideRight
                        text: root.player?.trackTitle || "Nothing on"
                        font { family: Theme.ui; pixelSize: 26; weight: Font.DemiBold }
                        color: Theme.fg
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.player?.trackArtist ?? ""
                        font { family: Theme.ui; pixelSize: 15 }
                        color: Theme.grey
                    }
                    Item { width: 1; height: 18 }
                    Seg { width: parent.width; height: 6; n: 24; f: root.player?.lengthSupported && root.player.length > 0 ? root.pos / root.player.length : 0 }
                    Item { width: 1; height: 16 }
                    Controls { player: root.player; size: 22; play: 52 }
                }
            }

            // the system: numbers, and the CPU over a minute as a dot matrix
            W {
                y: 480
                span: 3
                Grid {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 22
                    Stat { label: "cpu"; value: Math.round(SysInfo.cpu * 100) + "%" }
                    Stat { label: "mem"; value: root.d ? (root.d.mem.used / 1073741824).toFixed(1) + "G" : Math.round(SysInfo.mem * 100) + "%" }
                    Stat { label: root.gpu ? "gpu" : "temp"; value: Math.round(root.gpu ? root.d.gpu.temp ?? 0 : SysInfo.temp) + "°" }
                    Stat { label: "disk"; value: root.d?.disks?.[0] ? Math.round(root.d.disks[0].used / root.d.disks[0].size * 100) + "%" : "--" }
                }
                Column {
                    x: 344
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 34
                    spacing: 12
                    Lb { text: "cpu · 60 s" }
                    Spark { width: parent.width; height: 70; values: SysStats.cpuHistory; max: 100; points: 34; rows: 8 }
                }
                TapHandler { onTapped: PrefsState.show("telemetry") }
            }
        }
    }

    component W: Rectangle {
        property int span: 1
        property bool round
        width: span * 220 + (span - 1) * 20
        height: 220
        radius: round ? 110 : 40
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
    }
    component Meta: Row {
        property string icon
        property string text
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; text: parent.icon; font.pixelSize: 16 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: parent.text }
    }
    component Stat: Column {
        property string label
        property string value
        width: 130
        Lb { text: parent.label }
        Num { topPadding: lead + 6; text: parent.value }
    }
}
