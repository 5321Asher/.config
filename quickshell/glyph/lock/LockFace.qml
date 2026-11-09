import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../theme"
import "../widgets"
import "../services"

// What the lock looks like, after the reference's: the desktop as it was dissolves into a matrix of
// dots that grow apart and go out (and gathers back on unlock); the clock across the screen in Doto,
// the date and the weather as labels, the network and battery top right, the messages bottom left,
// and at the bottom the ring of dots, your name and the password pill: what you type is white dots,
// the caret red. A wrong password turns it red and shakes it. Only the main screen asks.
Item {
    id: root

    property string screenName: ""
    property bool main: true
    property bool preview: false
    readonly property real s: Math.max(0.8, Math.min(1.4, Math.min(width, height) / 1080))

    // 0 → 1 over the intro, back over the outro; each piece has its own phase (ease-out-quart)
    property real t: LockState.revealed ? 1 : 0
    Behavior on t { NumberAnimation { duration: LockState.revealed ? Theme.lockIntro : Theme.lockOutro } }
    function ph(a, b) { const x = Math.max(0, Math.min(1, (t - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var en: Qt.locale("en_US")
    readonly property var bat: UPower.displayDevice
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null
    readonly property bool fail: LockState.status === "denied" || LockState.status === "error"
    readonly property bool busy: LockState.status === "verifying"
    property real wave: 0
    NumberAnimation on wave { running: root.busy; from: 0; to: 1; duration: 700; loops: Animation.Infinite }

    // ---------------------------------------------------------------- the desktop, into dots
    Rectangle { anchors.fill: parent; color: Theme.bg }
    Item {
        id: dotted
        anchors.fill: parent
        readonly property real d: root.ph(0, 0.55)
        opacity: 1 - d
        visible: opacity > 0.01 && shot.status === Image.Ready
        layer.enabled: visible
        layer.effect: Dm { step: 3 + 22 * dotted.d }
        Image { id: shot; anchors.fill: parent; cache: false; source: root.screenName ? LockState.shotPath(root.screenName) : "" }
    }
    // the plain picture on top for the first moment, so it starts from exactly what was there
    Image {
        anchors.fill: parent
        cache: false
        source: shot.source
        opacity: 1 - root.ph(0, 0.18)
        visible: opacity > 0.01
    }
    // the halftone orb, breathing
    Orb {
        x: root.width / root.s - 720
        y: root.height / root.s - 580
        transformOrigin: Item.TopLeft
        scale: root.s
        opacity: 0.2 * root.ph(0.3, 0.9)
        visible: opacity > 0.01
    }

    Stage {
        id: stage
        s: root.s

        Lb {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 170
            text: root.en.toString(clock.date, "dddd · d MMMM")
            px: 14
            opacity: root.ph(0.25, 0.65)
            transform: Translate { y: 16 * (1 - root.ph(0.25, 0.65)) }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 230
            opacity: root.ph(0.2, 0.6)
            transform: Translate { y: -40 * (1 - root.ph(0.2, 0.6)) }
            readonly property real size: Math.min(400, stage.width / 3.3)
            Num { text: Qt.formatTime(clock.date, "HH"); font.pixelSize: parent.size }
            Num { text: ":"; font.pixelSize: parent.size; opacity: clock.date.getSeconds() % 2 ? 0.2 : 1 }
            Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: parent.size }
        }
        Lb {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 600
            opacity: root.ph(0.35, 0.75)
            transform: Translate { y: 16 * (1 - root.ph(0.35, 0.75)) }
            text: [Weather.ready ? `${Math.round(Weather.current.temp)}° ${Weather.describe(Weather.current.code)}` : "",
                   root.player?.trackTitle ? `${root.player.trackTitle} — ${root.player.trackArtist}` : ""].filter(Boolean).join("  ·  ")
        }

        Row {
            anchors { right: parent.right; rightMargin: 44 }
            y: 36
            spacing: 16
            opacity: root.ph(0.5, 0.9)
            Lb { anchors.verticalCenter: parent.verticalCenter; text: Net.ssid || (Net.wifiEnabled ? "offline" : "wi-fi off") }
            Icon { anchors.verticalCenter: parent.verticalCenter; text: Net.ssid ? "\u{F05A9}" : "\u{F05AA}"; font.pixelSize: 17 }
            Rectangle {
                visible: root.bat?.isLaptopBattery ?? false
                anchors.verticalCenter: parent.verticalCenter
                width: 27
                height: 13
                radius: 7
                color: "transparent"
                border { width: 1.5; color: Theme.grey }
                Rectangle { x: 3; y: 3; width: (parent.width - 6) * (root.bat?.percentage ?? 0); height: parent.height - 6; radius: 4; color: Theme.fg }
            }
            Lb { visible: root.bat?.isLaptopBattery ?? false; anchors.verticalCenter: parent.verticalCenter; text: Math.round((root.bat?.percentage ?? 0) * 100) }
        }
        Row {
            visible: Notifs.unread > 0
            opacity: root.ph(0.5, 0.9)
            x: 44
            anchors { bottom: parent.bottom; bottomMargin: 44 }
            spacing: 16
            Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F009A}"; font.pixelSize: 17 }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: `${Notifs.unread} notification${Notifs.unread === 1 ? "" : "s"}` }
        }
        Lb {
            visible: root.preview
            x: 44
            y: 40
            text: "preview · esc closes"
            opacity: root.ph(0.5, 0.9)
        }

        Column {
            visible: root.main
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 120 }
            spacing: 16

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                opacity: root.ph(0.4, 0.75)
                transform: Translate { y: 24 * (1 - root.ph(0.4, 0.75)) }
                Ring { anchors.fill: parent; n: 32; f: root.t > 0.45 ? 1 : 0; on: root.fail ? Theme.red : Theme.fg }
                Art { anchors { fill: parent; margins: 18 } url: `file://${Quickshell.env("HOME")}/.face`; step: 3 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: LockState.user
                font { family: Theme.ui; pixelSize: 22 }
                color: Theme.fg
                opacity: root.ph(0.45, 0.8)
                transform: Translate { y: 16 * (1 - root.ph(0.45, 0.8)) }
            }

            // the field: typed = dots; after the caret, unlit dots up to six
            Rectangle {
                id: pwd
                anchors.horizontalCenter: parent.horizontalCenter
                width: 58 + (380 - 58) * root.ph(0.55, 0.92)
                height: 58
                radius: 29
                opacity: root.ph(0.5, 0.65)
                color: Theme.s1
                border { width: 1; color: root.fail ? Theme.red : Theme.s3 }

                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    opacity: root.ph(0.8, 1)
                    Repeater {
                        id: typed
                        model: Math.min(LockState.buffer.length, 16)
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11
                            height: 11
                            radius: 5.5
                            color: root.fail ? Theme.red : Theme.fg
                            opacity: root.busy && Math.abs(root.wave * (typed.count + 2) - 1 - index) > 1.2 ? 0.3 : 1
                            NumberAnimation on scale { from: 0.2; to: 1; duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 24
                        color: Theme.red
                        opacity: clock.date.getSeconds() % 2 ? 0 : 1
                    }
                    Repeater {
                        model: Math.max(0, 6 - LockState.buffer.length)
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 11; height: 11; radius: 5.5; color: Theme.s3 }
                    }
                }

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: 10; duration: 80 }
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
                }
                Connections {
                    target: LockState
                    function onStatusChanged() { if (root.fail) shake.restart(); }
                }
            }
            Lb {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.ph(0.85, 1)
                text: root.busy ? "checking…" : LockState.status === "denied" ? "wrong password · try again"
                    : LockState.status === "error" ? (LockState.detail || "could not check · try again") : "enter password"
                color: root.fail ? Theme.red : Theme.grey
            }
        }
    }
}
