import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../launcher"
import "../quick"
import "../power"
import "../prefs"
import "../menus"
import "../utilities"

// The rail: a vertical pill at the left edge. At the top the mark (a ring of 16 dots: the index,
// right-click for the app launcher; its centre turns red while recording or dictating), then the
// workspaces as dots (the open one stretches into a white pill), the window's title on its side,
// the clock in Doto in the middle, then the tray (apps' icons as dots) and the status glyphs
// (click: quick settings), and the power glyph.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property real s: Theme.scaleFor(screen)

    anchors { left: true; top: true; bottom: true }
    implicitWidth: Math.ceil(Theme.railWidth * s)
    color: "transparent"
    WlrLayershell.namespace: "glyph-rail"

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int active: monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 1
    // six dots, more when a later one is open or busy
    readonly property int count: Math.min(10, Math.max(6, active, ...Hyprland.workspaces.values.filter(w => w.id > 0 && w.toplevels.values.length).map(w => w.id)))
    readonly property var top: Hyprland.activeToplevel
    readonly property bool live: Capture.recording || Voxtype.recording
    readonly property var bat: UPower.displayDevice
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink].filter(n => n) }
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real vol: sink?.audio?.volume ?? 0

    // the scratchpad (special:magic) shown over this screen's workspace
    property string special: ""
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name !== "activespecial") return;
            const [ws, mon] = e.data.split(",");
            if (mon === root.screen?.name) root.special = ws.replace(/^special:/, "");
        }
    }

    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Stage {
        id: stage
        s: root.s

        Rectangle {
            id: pill
            x: 14
            y: 14
            width: 64
            height: parent.height - 28
            radius: 10
            color: Theme.s1
            border { width: 1; color: Theme.s2 }

            WheelHandler { onWheel: e => root.go(e.angleDelta.y > 0 ? "-1" : "+1") }

            // the mark: a ring of dots; the centre is red while something is recording
            Item {
                id: mark
                anchors.horizontalCenter: parent.horizontalCenter
                y: 18
                width: 34
                height: 34
                Ring { anchors.fill: parent; n: 16; dot: 3; on: markMouse.containsMouse ? Theme.fg : Theme.grey }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 9
                    radius: 4.5
                    color: root.live ? Theme.red : Theme.fg
                    SequentialAnimation on opacity {
                        running: root.live
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.opacity = 1
                        NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                MouseArea {
                    id: markMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => e.button === Qt.RightButton ? (ExecState.open = !ExecState.open) : IndexState.toggle()
                }
            }

            // workspaces: the open one stretches into a white pill, busy ones grey, empty ones dim.
            // A ring over the open one while the scratchpad is shown; right-click: the overview
            Column {
                id: ws
                anchors.horizontalCenter: parent.horizontalCenter
                y: mark.y + mark.height + 24
                spacing: 8

                Rectangle {
                    visible: root.special !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: "transparent"
                    border { width: 2; color: Theme.fg }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${root.special}")`) }
                }
                Repeater {
                    model: ScriptModel { values: Array.from({ length: root.count }, (_, i) => i + 1) }

                    Rectangle {
                        required property int modelData
                        readonly property int n: modelData
                        readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                        readonly property bool on: root.active === n
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 8
                        height: on ? 28 : 8
                        radius: 4
                        color: on ? Theme.fg : occ ? Theme.grey : Theme.s3
                        Behavior on height { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: e => e.button === Qt.RightButton ? OverviewState.toggle() : root.go(parent.n)
                        }
                    }
                }
            }

            // the window's title on its side, from the workspaces down to the clock
            Item {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter
                y: ws.y + ws.height + 24
                width: 20
                height: Math.max(0, clk.y - 24 - y)
                clip: true
                Lb {
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    width: parent.height
                    rotation: 90
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: !!root.top && (root.top.workspace?.id ?? -1) === root.active
                    text: root.top ? `${(root.top.lastIpcObject?.class ?? "").split(".").pop()} · ${root.top.title}` : ""
                    px: 11
                }
            }

            // the clock in a column: hours over minutes, and the day. Click: the calendar
            Column {
                id: clk
                anchors.centerIn: parent
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "HH")
                    font.pixelSize: 30
                }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "mm")
                    font.pixelSize: 30
                }
                Lb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 8
                    text: Qt.locale("en_US").toString(clock.date, "ddd d")
                    px: 10
                }
                TapHandler { onTapped: PrefsState.show("almanac") }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }

            // the bottom: indicators that only show while something runs, the tray, the status glyphs
            Column {
                id: low
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 22 }
                spacing: 20

                // REC: the red dot and the time
                Column {
                    visible: Capture.recording
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 12; height: 12; radius: 6; color: Theme.red }
                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Capture.elapsedText; px: 9; color: Theme.fg }
                    TapHandler { onTapped: Capture.toggleRecording() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                // the focus timer: a ring that empties, the minutes left
                Item {
                    visible: FocusTimer.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34
                    height: 34
                    Ring { anchors.fill: parent; n: 16; dot: 3; f: 1 - FocusTimer.progress; on: FocusTimer.running ? Theme.fg : Theme.grey }
                    Lb { anchors.centerIn: parent; text: Math.ceil(FocusTimer.remaining / 60); px: 9; color: Theme.fg }
                    TapHandler { onTapped: PrefsState.show("chronometer") }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                // the tray: each app's icon as a matrix of dots; right-click for its menu
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    visible: SystemTray.items.values.length > 0
                    Repeater {
                        model: SystemTray.items
                        Item {
                            id: slot
                            required property var modelData
                            width: 20
                            height: 20
                            Image {
                                anchors.fill: parent
                                source: slot.modelData.icon
                                sourceSize: Qt.size(20, 20)
                                smooth: true
                                layer.enabled: true
                                layer.effect: Dm { step: 2.5 }
                                opacity: trayMouse.containsMouse ? 1 : 0.85
                            }
                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: e => {
                                    const it = slot.modelData;
                                    if (e.button === Qt.MiddleButton) it.secondaryActivate();
                                    else if (e.button === Qt.RightButton || it.onlyMenu) {
                                        const p = slot.mapToItem(null, slot.width, 0);
                                        TrayMenus.show(it, root.screen.name, p.x + 14 * root.s, p.y);
                                    } else it.activate();
                                }
                                onWheel: e => slot.modelData.scroll(e.angleDelta.y || e.angleDelta.x, e.angleDelta.y === 0)
                            }
                        }
                    }
                }

                // status: Wi-Fi, Bluetooth, sound (wheel: volume), messages, stay awake, battery,
                // the vulnerability watch when something needs a fix; a click opens quick settings
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20

                    Glyph {
                        text: !Net.wifiEnabled ? "\u{F05AA}" : Net.ssid ? "\u{F05A9}" : "\u{F092F}"
                        color: Net.ssid ? Theme.fg : Theme.grey
                    }
                    Glyph {
                        readonly property var bt: Bluetooth.defaultAdapter
                        text: bt?.enabled ? "\u{F00AF}" : "\u{F00B2}"
                        color: (bt?.devices.values.some(d => d.connected) ?? false) ? Theme.fg : Theme.grey
                    }
                    Glyph {
                        text: root.muted ? "\u{F075F}" : root.vol < 0.34 ? "\u{F057F}" : root.vol < 0.67 ? "\u{F0580}" : "\u{F057E}"
                        WheelHandler { onWheel: e => { if (root.sink?.audio) root.sink.audio.volume = Math.max(0, Math.min(1.5, root.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05))); } }
                    }
                    Glyph {
                        text: Notifs.dnd ? "\u{F009B}" : Notifs.unread > 0 ? "\u{F116B}" : "\u{F009A}"
                        color: Notifs.history.length ? Theme.fg : Theme.grey
                    }
                    Glyph { visible: StayAwake.on; text: "\u{F0176}" }
                    Glyph { visible: Status.vulnHigh > 0; text: "\u{F0565}"; color: Theme.red; quick: false
                            TapHandler { onTapped: PrefsState.show("telemetry") } }

                    // the battery stands upright, filled from the bottom; a bolt above while on AC
                    Column {
                        id: batCol
                        visible: root.bat?.isLaptopBattery ?? false
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        readonly property bool charging: root.bat?.state === UPowerDeviceState.Charging
                        readonly property bool low: UPower.onBattery && (root.bat?.percentage ?? 1) < 0.15
                        Icon { visible: !UPower.onBattery; anchors.horizontalCenter: parent.horizontalCenter; text: "\u{F140B}"; font.pixelSize: 14 }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 14
                            height: 26
                            radius: 7
                            color: "transparent"
                            border { width: 1.5; color: Theme.grey }
                            Rectangle {
                                x: 3
                                width: parent.width - 6
                                height: (parent.height - 6) * (root.bat?.percentage ?? 0)
                                anchors { bottom: parent.bottom; bottomMargin: 3 }
                                radius: 4
                                color: batCol.low ? Theme.red : Theme.fg
                                SequentialAnimation on opacity {
                                    running: batCol.charging
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round((root.bat?.percentage ?? 0) * 100); px: 10 }
                        TapHandler { onTapped: QuickState.open = !QuickState.open }
                    }

                    Glyph {
                        text: "\u{F0425}"
                        color: hovered ? Theme.fg : Theme.grey
                        quick: false
                        TapHandler { onTapped: PowerState.open = !PowerState.open }
                    }
                }
            }
        }
    }

    // a status glyph; click: quick settings (unless quick: false)
    component Glyph: Icon {
        property bool quick: true
        readonly property alias hovered: hov.hovered
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.fg
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: parent.quick; onTapped: QuickState.open = !QuickState.open }
    }
}
