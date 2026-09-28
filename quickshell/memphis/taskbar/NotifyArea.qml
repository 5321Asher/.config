import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "../theme"
import "../widgets"
import "../services"
import "../desk"
import "../menus"

// The notification area ("system tray"): a sunken box at the right end of the taskbar with the
// tray apps, Memphis's own status icons and the clock.
//   ● REC 0:12      screen recording: click to stop
//   hourglass       focus timer running: click for its window
//   microphone      dictating (voxtype)
//   envelope        notifications waiting: click for the inbox (grey while Do Not Disturb)
//   network         Wi-Fi / wired: click for Network Properties
//   speaker         volume: click for the slider, double-click for Volume Control
//   4:52 PM         point at it for the date; click for Date/Time Properties
Bevel {
    id: root

    required property var bar                       // the taskbar window (for popups)

    kind: "status"
    fill: Theme.face
    width: row.width + 12
    implicitHeight: Theme.taskButton

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink].filter(n => n) }

    Row {
        id: row
        x: 6
        height: parent.height
        spacing: 3

        // ---------------------------------------------------------------- tray apps
        Repeater {
            model: SystemTray.items
            Slot {
                id: app
                required property var modelData
                tip: modelData.tooltipTitle || modelData.title || modelData.id
                Image {
                    anchors.centerIn: parent
                    source: app.modelData.icon
                    sourceSize.width: Theme.trayIcon
                    sourceSize.height: Theme.trayIcon
                    width: Theme.trayIcon
                    height: Theme.trayIcon
                }
                onLeftClick: modelData.onlyMenu ? app.menu() : modelData.activate()
                onRightClick: app.menu()
                onMiddleClick: modelData.secondaryActivate()
                function menu() {
                    const p = app.mapToItem(null, 0, 0);
                    TrayMenus.show(modelData, root.bar.screen.name, p.x, root.bar.screen.height - Theme.taskbarHeight);
                }
            }
        }

        // ---------------------------------------------------------------- recording
        Slot {
            visible: Capture.recording
            width: recRow.width + 6
            tip: "Recording the screen: click to stop"
            Row {
                id: recRow
                x: 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Rectangle { width: 12; height: 12; radius: 6; color: "#e00000"; anchors.verticalCenter: parent.verticalCenter
                    border.width: 1; border.color: "#600000"
                    SequentialAnimation on opacity { running: Capture.recording; loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 } NumberAnimation { to: 1; duration: 600 } } }
                Txt { text: Capture.elapsedText }
            }
            onLeftClick: Capture.toggleRecording()
        }

        // ---------------------------------------------------------------- focus timer
        Slot {
            visible: FocusTimer.active
            width: ftRow.width + 6
            tip: FocusTimer.phaseLabel + (FocusTimer.running ? "" : " (paused)")
            Row {
                id: ftRow
                x: 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Icon { name: "appointment-soon"; fallback: "chronometer"; size: Theme.trayIcon; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: FocusTimer.remainingText }
            }
            onLeftClick: Desk.openPage("chronometer")
        }

        // ---------------------------------------------------------------- dictation
        Slot {
            visible: Voxtype.busy
            tip: Voxtype.recording ? "Dictating: Super+Z to finish" : "Transcribing…"
            Icon { anchors.centerIn: parent; name: "audio-input-microphone"; size: Theme.trayIcon }
            onLeftClick: Voxtype.toggle()
        }

        // ---------------------------------------------------------------- updates (Windows Update)
        Slot {
            visible: Updates.pending > 0 || Updates.high > 0
            tip: (Updates.pending > 0 ? Updates.pending + " updates are ready to install" : "")
                + (Updates.pending > 0 && Updates.count > 0 ? "\n" : "")
                + (Updates.count > 0 ? Updates.count + " packages with known vulnerabilities" + (Updates.high ? " (" + Updates.high + " high)" : "") : "")
            Icon { anchors.centerIn: parent; name: Updates.high > 0 ? "security-low" : "software-update-available"; size: Theme.trayIcon }
            onLeftClick: Desk.show("applet:system", { tab: "Security" })
        }

        // ---------------------------------------------------------------- notifications
        Slot {
            id: mail
            visible: Notifs.history.length > 0 || Notifs.dnd
            tip: Notifs.dnd ? "Do Not Disturb is on" : `${Notifs.history.length} message${Notifs.history.length === 1 ? "" : "s"}` + (Notifs.unread ? ` (${Notifs.unread} new)` : "")
            Icon {
                anchors.centerIn: parent
                name: Notifs.unread > 0 ? "mail-unread" : "mail-read"
                fallback: "mail-message-new"
                size: Theme.trayIcon
                opacity: Notifs.dnd ? 0.4 : 1
            }
            onLeftClick: Desk.toggle("messages")
            onRightClick: {
                const p = mail.mapToItem(null, 0, 0);
                Menus.show(root.bar.screen.name, "tray", [
                    { text: "Open Inbox", bold: true, run: () => Desk.show("messages") },
                    { text: "Do Not Disturb", check: Notifs.dnd, run: () => Notifs.dnd = !Notifs.dnd },
                    { sep: true },
                    { text: "Delete All", enabled: Notifs.history.length > 0, run: () => Notifs.clearAll() },
                ], p.x, root.bar.screen.height - Theme.taskbarHeight, { up: true });
            }
        }

        // ---------------------------------------------------------------- network
        Slot {
            id: net
            readonly property var bt: Bluetooth.defaultAdapter
            tip: (Net.wifiEnabled ? (Net.ssid ? `Wi-Fi: ${Net.ssid}` : "Wi-Fi: not connected") : "Wi-Fi off")
                + (Net.tsRunning ? "\nTailscale: on" : "")
                + (bt?.enabled ? "\nBluetooth: on" : "")
            Icon {
                anchors.centerIn: parent
                // bars for the connected network's signal (Chicago95: network-wireless-connected-00…100)
                readonly property int sig: Net.networks.find(n => n.inUse)?.signal ?? 0
                name: !Net.wifiEnabled ? "network-wireless-disconnected" : !Net.ssid ? "network-idle"
                    : "network-wireless-connected-" + (sig >= 88 ? "100" : sig >= 63 ? "75" : sig >= 38 ? "50" : sig >= 13 ? "25" : "00")
                fallback: "network-wired"
                size: Theme.trayIcon
            }
            Component.onCompleted: Net.refresh()
            onLeftClick: Desk.openPage("comms")
        }

        // ---------------------------------------------------------------- volume
        Slot {
            id: speaker
            readonly property real vol: root.sink?.audio?.volume ?? 0
            readonly property bool muted: root.sink?.audio?.muted ?? false
            tip: `Volume: ${Math.round(vol * 100)}%` + (muted ? " (muted)" : "")
            Icon {
                anchors.centerIn: parent
                name: speaker.muted ? "audio-volume-muted" : speaker.vol > 0.66 ? "audio-volume-high"
                    : speaker.vol > 0.33 ? "audio-volume-medium" : "audio-volume-low"
                size: Theme.trayIcon
            }
            onLeftClick: volPop.visible = !volPop.visible
            onDoubleClick: { volPop.visible = false; Desk.show("volume"); }
            onRightClick: {
                const p = speaker.mapToItem(null, 0, 0);
                Menus.show(root.bar.screen.name, "tray", [
                    { text: "Open Volume Controls", bold: true, run: () => Desk.show("volume") },
                    { text: "Adjust Audio Properties", run: () => Desk.show("applet:multimedia", { tab: "Audio" }) },
                    { sep: true },
                    { text: "Mute", check: speaker.muted, run: () => { if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted; } },
                ], p.x, root.bar.screen.height - Theme.taskbarHeight, { up: true });
            }
            onWheeled: d => { if (root.sink?.audio) root.sink.audio.volume = Math.max(0, Math.min(1, speaker.vol + d * 0.05)); }
            VolumePopup { id: volPop; target: speaker; sink: root.sink }
        }

        // ---------------------------------------------------------------- clock
        Item {
            id: clock
            width: clockText.implicitWidth + 12
            height: parent.height
            Txt {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatTime(now.date, "h:mm AP")
            }
            SystemClock { id: now; precision: SystemClock.Minutes }
            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => {
                    if (e.button === Qt.RightButton) {
                        const p = clock.mapToItem(null, 0, 0);
                        Menus.show(root.bar.screen.name, "tray", [
                            { text: "Adjust Date/Time", bold: true, run: () => Desk.openPage("almanac") },
                            { text: "Weather", run: () => Desk.show("applet:datetime", { tab: "Weather" }) },
                            { sep: true },
                            { text: "Control Panel", run: () => Desk.show("control") },
                            { text: "Task Manager", run: () => Desk.openPage("telemetry") },
                        ], p.x, root.bar.screen.height - Theme.taskbarHeight, { up: true });
                    } else Desk.openPage("almanac");
                }
            }
            Tip { target: clock; hovered: clockMouse.containsMouse; text: Qt.formatDate(now.date, "dddd, MMMM d, yyyy") }
        }
    }

    // One notification-area icon: a click target with a tooltip
    component Slot: Item {
        id: slot
        property string tip: ""
        signal leftClick()
        signal rightClick()
        signal middleClick()
        signal doubleClick()
        signal wheeled(int dir)
        width: Theme.traySlot
        height: parent ? parent.height : Theme.taskButton
        MouseArea {
            id: sm
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => e.button === Qt.RightButton ? slot.rightClick() : e.button === Qt.MiddleButton ? slot.middleClick() : slot.leftClick()
            onDoubleClicked: e => { if (e.button === Qt.LeftButton) slot.doubleClick(); }
            onWheel: e => slot.wheeled(e.angleDelta.y > 0 ? 1 : -1)
        }
        Tip { target: slot; hovered: sm.containsMouse; text: slot.tip }
    }
}
