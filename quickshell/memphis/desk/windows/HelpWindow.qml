import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../widgets"
import ".."

// Memphis Help, in the style of 98's Windows Help: Contents (a few short topics) and Index (every
// keybind, from ~/.config/walker/keybinds.txt, the same cheat sheet Walker shows; type to find one).
Win {
    id: root

    title: "Memphis Help"
    icon: "help-browser"
    minButton: false

    property int topic: 0
    property var binds: []
    property string find: ""

    FileView {
        path: Quickshell.env("HOME") + "/.config/walker/keybinds.txt"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.binds = text().split("\n").filter(l => l.trim() && !l.trim().startsWith("#") && l.includes("|"))
            .map(l => { const i = l.indexOf("|"); return { keys: l.slice(0, i).trim(), what: l.slice(i + 1).trim() }; })
    }

    readonly property var topics: [
        { title: "Welcome to Memphis", body:
`Memphis is this desktop dressed as a computer from around 1998.

The Start button (or Super + Space) opens the Start menu: your programs, recent documents, Control Panel and the shared menus (Trigger, Style, Power) that every setup has.

Super + Ctrl + Space opens Run…, which is also the quickest way to start a program: type a few letters and press Enter.

Your windows still tile. Their buttons on the taskbar switch between them; click the active one to minimise it, and again to bring it back.` },
        { title: "The taskbar", body:
`From the left: Start; the workspace buttons (click one to go there, scroll over them to step, right-click for the overview); a button for each window on this screen's workspace; and the notification area.

In the notification area: your tray programs; a red dot while the screen is being recorded (click to stop); an hourglass while the focus timer runs; an envelope when there are notifications (click for the Inbox, right-click for Do Not Disturb); the network; the speaker (click for the volume, double-click for Volume Control); and the clock (point at it for the date, click for Date/Time Properties).` },
        { title: "Control Panel", body:
`Start → Settings → Control Panel has everything the other setups keep in their side panels.

The pane on its left holds the everyday switches: Wi-Fi, Bluetooth, Tailscale, Do Not Disturb, Stay Awake and "lights follow the theme", the volume and brightness, screenshots and recording, dictation, and the power buttons.

Double-click an icon for its Properties: Date/Time (with the weather and the moon), Display (screens, brightness, colour scheme), Multimedia (what's playing, volume per program, speakers and microphone), Network (Wi-Fi, Bluetooth, Tailscale), System (performance, devices), Lighting, Focus Timer, Power and Claude.` },
        { title: "Colour schemes and setups", body:
`Display Properties → Appearance → Scheme picks one of Memphis's colour schemes (Windows Standard, Rainy Day, Brick, Eggplant, Marine, Wheat, High Contrast Black). Each has its own wallpaper.

Start → Settings → Setup switches the whole desktop to another setup; its colours, fonts and panels come with it.` },
        { title: "Keyboard shortcuts", body: "" },
    ]

    Tabs {
        id: tabs
        x: Theme.pad
        y: Theme.pad
        width: 220
        height: parent.height - Theme.pad * 2 - 40
        tabs: ["Contents", "Index"]

        ListBox {
            anchors.fill: parent
            model: root.topics
            currentIndex: root.topic
            iconOf: t => "help-contents"
            textOf: t => t.title
            onClicked: i => root.topic = i
        }
        Column {
            anchors.fill: parent
            spacing: 6
            Txt { text: "Type the first few letters:" }
            Field {
                width: parent.width
                text: root.find
                onEdited: { root.find = text; root.topic = root.topics.length - 1; }
            }
            Txt { text: "Then click Display." }
        }
    }

    // the topic, on a white page
    Bevel {
        id: page
        kind: "sunken"
        fill: Theme.window
        x: tabs.x + tabs.width + Theme.gap
        y: Theme.pad
        width: parent.width - x - Theme.pad
        height: tabs.height

        Flickable {
            id: flick
            x: 14; y: 12
            width: parent.width - 28 - (bar.visible ? bar.width : 0)
            height: parent.height - 24
            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: flick.width
                spacing: 10
                Text {
                    width: parent.width
                    text: root.topics[root.topic].title
                    color: Theme.dark ? Theme.windowText : "#000080"
                    font.family: Theme.fontSerif
                    font.pixelSize: 24
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                Txt {
                    visible: root.topic < root.topics.length - 1
                    width: parent.width
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignTop
                    color: Theme.windowText
                    text: root.topics[root.topic].body
                }
                // Keyboard shortcuts: the cheat sheet, filtered by the Index box
                Repeater {
                    model: root.topic === root.topics.length - 1
                        ? root.binds.filter(b => !root.find || (b.keys + " " + b.what).toLowerCase().includes(root.find.toLowerCase())) : []
                    Row {
                        required property var modelData
                        width: body.width
                        spacing: 10
                        Txt { width: 230; text: modelData.keys; bold: true; color: Theme.windowText; elide: Text.ElideRight }
                        Txt { width: parent.width - 240; text: modelData.what; color: Theme.windowText; wrapMode: Text.Wrap }
                    }
                }
            }
        }
        Scroll { id: bar; flick: flick; x: parent.width - width - 2; y: 2; height: parent.height - 4 }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.pad
        y: parent.height - Theme.pad - Theme.button
        spacing: 8
        Btn { text: "Edit Shortcuts…"; onClicked: Quickshell.execDetached(["sh", "-c", "kitty -e ${EDITOR:-nvim} ~/.config/walker/keybinds.txt"]) }
        Btn { text: "Close"; isDefault: true; onClicked: root.closeRequested() }
    }
}
