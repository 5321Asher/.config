import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../theme"
import "../../widgets"
import "../../services"
import "../../menus"
import ".."

// Control Panel, as 98 showed it with "View as Web Page" on: an Explorer window with the applet
// icons on the right and the web-view pane down the left. Here the pane holds the everyday
// switches (what the other setups keep on a quick-settings page): Wi-Fi, Bluetooth, Tailscale,
// Do Not Disturb, Stay Awake, lights follow the theme; volume, microphone and brightness;
// screenshots, recording and dictation; and the power buttons.
// Double-click an icon (or select it and press Enter) for its Properties.
Win {
    id: root

    title: "Control Panel"
    icon: "preferences-system"
    minButton: true
    onMinRequested: closeRequested()
    status: sel >= 0 ? applets[sel].about : `${applets.length} object(s)`
    statusParts: ["My Computer"]
    menus: [
        { title: "File", items: () => [
            { text: "Open", bold: true, enabled: sel >= 0, run: () => openApplet(sel) },
            { sep: true },
            { text: "Close", run: () => root.closeRequested() },
        ] },
        { title: "View", items: () => [
            { text: "Refresh", hint: "F5", run: () => { Net.refresh(); Brightness.scan(); } },
        ] },
        { title: "Help", items: () => [
            { text: "Help Topics", run: () => Desk.show("help") },
            { sep: true },
            { text: "About Memphis", run: () => Desk.show("applet:system", { tab: "General" }) },
        ] },
    ]
    onMenuRequested: (menu, x, y) => Menus.show(Desk.wins.control?.screen ?? Desk.focusedScreen(), "menubar", menu.items(), x, y, {})

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n) }

    Component.onCompleted: {
        Net.refresh();
        if (!Brightness.scanned) Brightness.scan();
        if (!Rgb.scanned) Rgb.scan();
    }

    // ---------------------------------------------------------------- the applets
    readonly property var applets: [
        { id: "datetime", name: "Date/Time", icon: "preferences-system-time", about: "Changes the date, time and time zone; shows the calendar, the weather and the moon." },
        { id: "display", name: "Display", icon: "preferences-desktop-display", about: "Changes your screens' layout, resolution and brightness, and the colour scheme." },
        { id: "multimedia", name: "Multimedia", icon: "applications-multimedia", about: "What's playing, the volume of each program, and your speakers and microphone." },
        { id: "volume", name: "Volume Control", icon: "multimedia-volume-control", about: "Sets the volume of your speakers and of each program." },
        { id: "network", name: "Network", icon: "network-workgroup", about: "Connects to Wi-Fi networks, Bluetooth devices and your Tailscale network." },
        { id: "system", name: "System", icon: "computer", about: "Shows how hard your computer is working, and your drives, batteries and fans." },
        { id: "lighting", name: "Lighting", icon: "color-select", about: "Sets the colour of your RGB lights, or lets them follow the colour scheme." },
        { id: "timer", name: "Focus Timer", icon: "appointment-soon", about: "A focus timer and pomodoro, shown in the notification area while it runs." },
        { id: "power", name: "Power Management", icon: "preferences-system-power", about: "Keeps the computer awake, and locks, stands by or shuts it down." },
        { id: "messages", name: "Notifications", icon: "internet-mail", about: "Your notifications, and Do Not Disturb." },
        { id: "claude", name: "Claude", icon: "help-about", about: "Your Claude account: usage and limits." },
        { id: "help", name: "Help", icon: "help-browser", about: "How Memphis works, and every keyboard shortcut." },
    ]
    property int sel: -1
    function openApplet(i) {
        const a = applets[i];
        if (!a) return;
        if (a.id === "volume" || a.id === "messages" || a.id === "help") Desk.show(a.id);
        else Desk.show("applet:" + a.id);
    }
    Keys.onReturnPressed: openApplet(sel)
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) { sel = Math.min(applets.length - 1, sel + (e.key === Qt.Key_Down ? grid.cols : 1)); e.accepted = true; }
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) { sel = Math.max(0, sel - (e.key === Qt.Key_Up ? grid.cols : 1)); e.accepted = true; }
        else if (e.key === Qt.Key_F5) { Net.refresh(); e.accepted = true; }
    }

    // Close first, then act (so a screenshot doesn't catch the window)
    function closeThen(fn) { root.closeRequested(); later.fn = fn; later.restart(); }
    Timer { id: later; property var fn; interval: 150; onTriggered: fn() }

    // ---------------------------------------------------------------- address bar
    Row {
        id: addressBar
        x: 0; y: 0
        width: parent.width
        height: Theme.field + 6
        spacing: 6
        Txt { height: parent.height; leftPadding: 6; text: "Address" }
        Field {
            width: parent.width - 80
            y: 3
            readOnly: true
            text: "Control Panel"
        }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: addressBar.height + 2

        // ---------------------------------------------------------------- the web-view pane
        Bevel {
            id: pane
            kind: "sunken"
            fill: Theme.window
            width: Theme.webPane + 24
            height: parent.height

            Flickable {
                id: flick
                x: 2; y: 2
                width: parent.width - 4 - (bar.visible ? bar.width : 0)
                height: parent.height - 4
                clip: true
                contentHeight: web.implicitHeight + 20
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: web
                    x: 12
                    y: 10
                    width: flick.width - 24
                    spacing: 6

                    Icon { name: "preferences-system"; size: 40 }
                    Text {
                        text: "Control\nPanel"
                        color: Theme.windowText
                        font.family: Theme.fontBanner
                        font.pixelSize: 22
                        lineHeight: 0.9
                    }
                    // 98's web-view rule: a thin line fading through the title colours
                    Rectangle {
                        width: parent.width
                        height: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.title }
                            GradientStop { position: 0.5; color: Theme.title2 }
                            GradientStop { position: 1; color: Theme.window }
                        }
                    }
                    Txt {
                        width: parent.width
                        wrapMode: Text.Wrap
                        color: Theme.windowText
                        text: root.sel >= 0 ? root.applets[root.sel].name + "\n\n" + root.applets[root.sel].about
                            : "Use the settings in Control Panel to personalize your computer.\n\nSelect an item to view its description."
                    }

                    Heading { text: "Switches" }
                    Check { text: "Wi-Fi" + (Net.ssid ? ` (${Net.ssid})` : ""); checked: Net.wifiEnabled; onToggled: Net.toggleWifi() }
                    Check {
                        text: "Bluetooth"
                        enabled: root.bt !== null
                        checked: root.bt?.enabled ?? false
                        onToggled: root.bt.enabled = !root.bt.enabled
                    }
                    Check {
                        text: "Tailscale" + (Net.tsRunning ? ` (${Net.tsPeersOnline} online)` : "")
                        enabled: Net.tsAvailable && Net.tsBusy === ""
                        checked: Net.tsRunning
                        onToggled: Net.toggleTailscale()
                    }
                    Check { text: "Do Not Disturb"; checked: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
                    Check { text: "Stay awake"; checked: StayAwake.on; onToggled: StayAwake.on = !StayAwake.on }
                    Check {
                        text: "Lights follow the scheme"
                        enabled: Rgb.available
                        checked: Rgb.followWallpaper
                        onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper)
                    }
                    Txt { visible: Net.tsError !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Net.tsError }

                    Heading { text: "Levels" }
                    Level { label: "Speakers"; node: root.sink }
                    Level { label: "Microphone"; node: root.source }
                    Repeater {
                        model: Brightness.displays
                        Column {
                            required property var modelData
                            required property int index
                            width: web.width
                            Txt { text: (modelData.name || "Display") + ": " + Math.round(modelData.value * 100) + "%"; color: Theme.windowText }
                            TrackBar { width: parent.width; ticks: 0; value: modelData.value; onMoved: v => Brightness.set(index, v) }
                        }
                    }

                    Heading { text: "Capture" }
                    Link { text: "Screenshot of an area"; onClicked: root.closeThen(() => Capture.screenshot("region")) }
                    Link { text: "Screenshot of the screen"; onClicked: root.closeThen(() => Capture.screenshot("screen")) }
                    Link { text: "Copy text from the screen"; onClicked: root.closeThen(() => Capture.ocr()) }
                    Link {
                        text: Capture.recording ? "Stop recording (" + Capture.elapsedText + ")" : "Record the screen"
                        enabled: Capture.recording || Capture.recorder !== ""
                        onClicked: Capture.recording ? Capture.toggleRecording() : root.closeThen(() => Capture.toggleRecording())
                    }

                    Heading { text: "Dictation"; visible: Voxtype.available }
                    Link {
                        visible: Voxtype.available
                        text: !Voxtype.running ? "Start the dictation service" : Voxtype.recording ? "Stop and type it (" + Voxtype.elapsedText + ")" : "Start dictating"
                        enabled: !Voxtype.transcribing
                        onClicked: Voxtype.running && !Voxtype.recording ? root.closeThen(() => Voxtype.toggle()) : Voxtype.toggle()
                    }
                    Link { visible: Voxtype.busy; text: "Cancel dictation"; onClicked: Voxtype.cancel() }

                    Heading { text: "Power" }
                    Link { text: "Lock the computer"; onClicked: root.closeThen(() => Quickshell.execDetached(["loginctl", "lock-session"])) }
                    Link { text: "Stand by"; onClicked: root.closeThen(() => Quickshell.execDetached(["systemctl", "suspend"])) }
                    Link { text: "Log off…"; onClicked: Desk.show("logoff") }
                    Link { text: "Restart or shut down…"; onClicked: Desk.show("shutdown") }
                }
            }
            Scroll { id: bar; flick: flick; x: parent.width - width - 2; y: 2; height: parent.height - 4 }
        }

        // ---------------------------------------------------------------- the icons
        Bevel {
            kind: "sunken"
            fill: Theme.window
            x: pane.width + 4
            width: parent.width - x
            height: parent.height

            MouseArea { anchors.fill: parent; onClicked: root.sel = -1 }

            Grid {
                id: grid
                x: 10; y: 10
                readonly property int cellW: 110
                readonly property int cols: Math.max(1, Math.floor((parent.width - 20) / cellW))
                columns: cols
                rowSpacing: 8
                Repeater {
                    model: root.applets
                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool on: root.sel === index
                        width: grid.cellW
                        height: 88

                        Icon {
                            id: ic
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 4
                            name: cell.modelData.icon
                            size: 40
                        }
                        // selected: the icon gets the highlight colour dithered over it
                        Rectangle {
                            anchors.fill: ic
                            visible: cell.on
                            color: Theme.alpha(Theme.select, 0.45)
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: ic.y + ic.height + 4
                            width: Math.min(parent.width - 4, label.implicitWidth + 6)
                            height: label.height + 2
                            color: cell.on ? Theme.select : "transparent"
                            Txt {
                                id: label
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 1
                                width: Math.min(implicitWidth, cell.width - 10)
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                text: cell.modelData.name
                                color: cell.on ? Theme.selectText : Theme.windowText
                            }
                            FocusRect { anchors.fill: parent; visible: cell.on && root.activeFocus; color: Theme.selectText }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.forceActiveFocus(); root.sel = cell.index; }
                            onDoubleClicked: root.openApplet(cell.index)
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- pane pieces
    component Heading: Column {
        property alias text: h.text
        width: web.width
        spacing: 2
        topPadding: 8
        Txt { id: h; bold: true; color: Theme.windowText }
        Rectangle { width: parent.width; height: 1; color: Theme.shadow }
    }
    // a web-view hyperlink: blue, underlined under the pointer
    component Link: Text {
        id: l
        signal clicked()
        width: web.width
        wrapMode: Text.Wrap
        color: !enabled ? Theme.grayText : Theme.dark ? "#00ffff" : Theme.link
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.underline: lm.containsMouse
        renderType: Text.NativeRendering
        MouseArea {
            id: lm
            anchors.fill: parent
            hoverEnabled: true
            enabled: l.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: l.clicked()
        }
    }
    component Level: Column {
        id: lv
        property string label
        property PwNode node
        width: web.width
        Row {
            spacing: 6
            Txt { text: lv.label + ": " + Math.round((lv.node?.audio?.volume ?? 0) * 100) + "%"; color: Theme.windowText; width: web.width - 70 }
            Check {
                text: "Mute"
                checked: lv.node?.audio?.muted ?? false
                onToggled: if (lv.node?.audio) lv.node.audio.muted = !lv.node.audio.muted
            }
        }
        TrackBar {
            width: parent.width
            ticks: 0
            value: lv.node?.audio?.volume ?? 0
            onMoved: v => { if (lv.node?.audio) lv.node.audio.volume = v; }
        }
    }
}
