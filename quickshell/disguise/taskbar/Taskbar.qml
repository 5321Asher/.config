import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../flyouts"
import "../services"
import "../settings"
import "../utilities"

// Windows 11's taskbar, along the bottom of every screen, 48 px of Acrylic:
//   left     Widgets: the weather now (opens the Widgets board)
//   centre   Start, Search, Task View, then your pinned apps and open windows (a pill under the
//            ones that are open, a longer accent one under the active app)
//   right    ^ (hidden tray icons), recording / voice typing / focus / update notices, the
//            network-volume-battery button (Quick Settings), the clock (notifications and the
//            calendar), and the sliver at the very edge that shows the desktop
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property string sname: modelData.name
    readonly property bool narrow: width < 1100

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.taskbarHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "disguise-taskbar"
    exclusiveZone: Theme.taskbarHeight

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.taskbar, Theme.taskbarAlpha)
        Rectangle { width: parent.width; height: 1; color: Theme.dark ? Qt.alpha("#ffffff", 0.08) : Qt.alpha("#000000", 0.08) }
    }

    // where a flyout's menu should grow up from, in the flyout layer's coordinates
    function menuY() { return root.modelData.height - Theme.taskbarHeight - Theme.flyoutGap; }
    function xOf(item) { return item.mapToItem(null, item.width / 2, 0).x; }
    function flyout(k, o) { Flyouts.toggle(k, sname, o); }
    function open(k) { return Flyouts.kind === k && Flyouts.screen === sname && !Flyouts.closing; }

    // ---------------------------------------------------------------- left: Widgets (the weather)
    TaskItem {
        id: widgets
        x: 4
        width: weatherRow.width + 20
        lit: root.open("widgets")
        onClicked: root.flyout("widgets")
        Row {
            id: weatherRow
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            WeatherIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 24
                code: Weather.current?.code ?? 2
                day: Weather.current?.isDay ?? true
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Txt { text: Weather.ready ? Math.round(Weather.current.temp) + "°" + (Config.tempUnit === "fahrenheit" ? "F" : "C") : "Weather"; size: Theme.caption; strong: true }
                Txt { visible: !root.narrow; text: Weather.ready ? Weather.describe(Weather.current.code) : ""; size: Theme.caption; level: 2 }
            }
        }
    }

    // ---------------------------------------------------------------- centre
    Row {
        id: centre
        anchors.verticalCenter: parent.verticalCenter
        // centred on the screen; nudged left if it would run into the right-hand side
        x: Math.max(widgets.x + widgets.width + 8, Math.min(Math.round((root.width - width) / 2), right.x - width - 8))
        spacing: 4

        // Start: the four panes
        TaskItem {
            id: start
            width: 44
            lit: root.open("start")
            onClicked: root.flyout("start")
            onRightClicked: WinX.show(root.sname, root.xOf(start), root.menuY())
            Logo {
                anchors.centerIn: parent
                size: start.down ? 16 : 20
                Behavior on size { NumberAnimation { duration: 80 } }
            }
            Tip { target: start; hovered: start.hovered && !start.lit; text: "Start" }
        }

        // Search: the box, or just the magnifier when there's no room
        TaskItem {
            id: search
            width: root.narrow ? 44 : 172
            lit: root.open("search")
            onClicked: root.flyout("search")
            Rectangle {
                visible: !root.narrow
                anchors.fill: parent
                anchors.margins: 4
                radius: height / 2
                color: Theme.dark ? Qt.alpha("#ffffff", search.hovered ? 0.1 : 0.06) : Qt.alpha("#ffffff", search.hovered ? 0.95 : 0.75)
                border.width: 1
                border.color: Theme.dark ? Qt.alpha("#ffffff", 0.08) : Qt.alpha("#000000", 0.08)
                Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; g: ""; size: 14; color: Theme.text2 }
                Txt { x: 36; anchors.verticalCenter: parent.verticalCenter; text: "Search"; level: 2 }
            }
            Glyph { visible: root.narrow; anchors.centerIn: parent; g: ""; size: 18 }
        }

        // Task View
        TaskItem {
            id: taskView
            width: 44
            lit: TaskView.open
            onClicked: TaskView.toggle()
            Glyph { anchors.centerIn: parent; g: ""; size: 18 }
            Tip { target: taskView; hovered: taskView.hovered; text: "Task View" }
        }

        TaskButtons {
            monitor: root.monitor
            screenName: root.sname
            menuY: root.menuY()
        }
    }

    // ---------------------------------------------------------------- right
    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // ^ hidden icons
        TaskItem {
            id: chevron
            width: 28
            lit: root.open("tray")
            onClicked: root.flyout("tray", { x: root.xOf(chevron) })
            Glyph { anchors.centerIn: parent; g: root.open("tray") ? "" : ""; size: 12 }
            Tip { target: chevron; hovered: chevron.hovered; text: "Show hidden icons" }
        }

        // recording: the red dot and the time; click to stop
        TaskItem {
            id: rec
            visible: Capture.recording
            width: recRow.width + 16
            onClicked: Capture.toggleRecording()
            Row {
                id: recRow
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Rectangle {
                    width: 10; height: 10; radius: 5; color: "#e81123"
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity { running: Capture.recording; loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
                }
                Txt { text: Capture.elapsedText; size: Theme.caption }
            }
            Tip { target: rec; hovered: rec.hovered; text: "Recording the screen: click to stop" }
        }

        // voice typing
        TaskItem {
            id: voice
            visible: Voxtype.busy
            width: 32
            onClicked: Voxtype.toggle()
            Glyph { anchors.centerIn: parent; g: ""; size: 16; color: Voxtype.recording ? Theme.accentLink : Theme.text }
            Tip { target: voice; hovered: voice.hovered; text: Voxtype.recording ? "Voice typing: listening" : "Voice typing: writing it down…" }
        }

        // a focus session
        TaskItem {
            id: focusItem
            visible: FocusTimer.active
            width: focusRow.width + 16
            onClicked: root.flyout("notif")
            Row {
                id: focusRow
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Ring { width: 16; height: 16; thickness: 2; value: 1 - FocusTimer.progress; track: Theme.subtle; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: FocusTimer.remainingText; size: Theme.caption }
            }
            Tip { target: focusItem; hovered: focusItem.hovered; text: FocusTimer.phaseLabel + (FocusTimer.running ? "" : " (paused)") }
        }

        // Windows Update: updates waiting, or a serious vulnerability
        TaskItem {
            id: upd
            visible: Updates.pending > 0 || Updates.high > 0
            width: 32
            onClicked: SettingsApp.open("update")
            Glyph { anchors.centerIn: parent; g: Updates.high > 0 ? "" : ""; size: 16; color: Updates.high > 0 ? Theme.warn : Theme.text }
            Rectangle { visible: Updates.high > 0; x: 20; y: 10; width: 8; height: 8; radius: 4; color: Theme.danger }
            Tip {
                target: upd; hovered: upd.hovered
                text: (Updates.pending > 0 ? Updates.pending + " updates are ready to install" : "")
                    + (Updates.pending > 0 && Updates.count > 0 ? "\n" : "")
                    + (Updates.count > 0 ? Updates.count + " packages with known vulnerabilities" + (Updates.high ? " (" + Updates.high + " high)" : "") : "")
            }
        }

        // network · volume · battery → Quick Settings
        SystemButton {
            lit: root.open("quick")
            onClicked: root.flyout("quick")
        }

        // the clock → notifications and the calendar
        TaskItem {
            id: clockItem
            width: clockCol.width + (Notifs.dnd || Notifs.unread ? 38 : 20)
            lit: root.open("notif")
            onClicked: root.flyout("notif")
            SystemClock { id: clock; precision: SystemClock.Minutes }
            Column {
                id: clockCol
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                Txt { anchors.right: parent.right; text: Qt.formatTime(clock.date, "h:mm AP"); size: Theme.caption }
                Txt { anchors.right: parent.right; text: Qt.formatDate(clock.date, "M/d/yyyy"); size: Theme.caption }
            }
            // do-not-disturb bell, or the count of new notifications
            Glyph {
                visible: Notifs.dnd
                x: clockCol.x + clockCol.width + 8
                anchors.verticalCenter: parent.verticalCenter
                g: ""; size: 14
            }
            Rectangle {
                visible: !Notifs.dnd && Notifs.unread > 0
                x: clockCol.x + clockCol.width + 6
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(18, badge.implicitWidth + 8); height: 18; radius: 9
                color: Theme.accent
                Txt { id: badge; anchors.centerIn: parent; text: Math.min(99, Notifs.unread); size: 11; color: Theme.accentText; strong: true }
            }
            Tip { target: clockItem; hovered: clockItem.hovered && !clockItem.lit; text: Qt.formatDate(clock.date, "dddd, MMMM d, yyyy") }
        }

        // show the desktop: the thin strip at the edge
        Item {
            width: 10
            height: Theme.taskbarHeight
            Rectangle { anchors.centerIn: parent; width: 1; height: 16; color: Theme.divider; visible: sd.containsMouse }
            MouseArea { id: sd; anchors.fill: parent; hoverEnabled: true; onClicked: ShowDesktop.toggle(root.monitor) }
        }
    }

    // ---------------------------------------------------------------- pieces
    // A taskbar button: a rounded highlight under the pointer (and while its flyout is open)
    component TaskItem: Item {
        id: ti
        property bool lit: false
        readonly property alias hovered: tm.containsMouse
        readonly property alias down: tm.pressed
        signal clicked()
        signal rightClicked()
        height: 40
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: ti.down ? Theme.subtle2 : ti.hovered || ti.lit ? Qt.alpha(Theme.text, Theme.dark ? 0.08 : 0.055) : "transparent"
            border.width: ti.lit || ti.hovered ? 1 : 0
            border.color: Qt.alpha(Theme.text, Theme.dark ? 0.05 : 0.03)
        }
        MouseArea {
            id: tm
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => e.button === Qt.RightButton ? ti.rightClicked() : ti.clicked()
        }
    }

    component SystemButton: TaskItem {
        id: sb
        readonly property PwNode sink: Pipewire.defaultAudioSink
        PwObjectTracker { objects: [sb.sink].filter(n => n) }
        readonly property real vol: sink?.audio?.volume ?? 0
        readonly property bool muted: sink?.audio?.muted ?? false
        readonly property var battery: UPower.displayDevice
        readonly property bool hasBattery: battery?.isLaptopBattery ?? false
        readonly property real pct: !battery ? 0 : battery.percentage > 1 ? battery.percentage : battery.percentage * 100
        readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged
        readonly property int sig: Net.networks.find(n => n.inUse)?.signal ?? (Net.ssid ? 100 : 0)
        width: sysRow.width + 20
        Component.onCompleted: Net.refresh()
        Row {
            id: sysRow
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Glyph {
                g: !Net.wifiEnabled ? "" : !Net.ssid ? "" : sb.sig >= 75 ? "" : sb.sig >= 50 ? "" : sb.sig >= 25 ? "" : ""
                size: 16
            }
            Glyph {
                g: sb.muted ? "" : sb.vol > 0.66 ? "" : sb.vol > 0.33 ? "" : sb.vol > 0 ? "" : ""
                size: 16
            }
            Glyph {
                visible: sb.hasBattery
                g: String.fromCharCode((sb.charging ? 0xebab : 0xeba0) + Math.round(sb.pct / 10))
                size: 16
            }
        }
        // the wheel changes the volume, as it does over Windows' speaker
        WheelHandler {
            onWheel: e => { if (sb.sink?.audio) sb.sink.audio.volume = Math.max(0, Math.min(1, sb.vol + (e.angleDelta.y > 0 ? 0.02 : -0.02))); }
        }
        Tip {
            target: sb; hovered: sb.hovered && !sb.lit
            text: (Net.ssid ? Net.ssid + "\nInternet access" : Net.wifiEnabled ? "Not connected" : "Wi-Fi is off")
                + "\nSpeakers: " + Math.round(sb.vol * 100) + "%" + (sb.muted ? " (muted)" : "")
                + (sb.hasBattery ? "\nBattery: " + Math.round(sb.pct) + "%" + (sb.charging ? " (plugged in)" : " remaining") : "")
        }
    }
}
