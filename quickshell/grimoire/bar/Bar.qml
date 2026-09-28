import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../codex"
import "../launcher"
import "../utilities"

// The bar, along the top of every screen: a strip of tooled leather with a gilt lower edge, like the
// head of a book. In the corner the clasp (the table of contents); then the chapters in Roman
// numerals, a silk ribbon hanging from the open one (below the bar, over the page); the running head
// (the chapter and the page you're on) in the middle; on the right whatever is running (a recording,
// the scribe, the hourglass), the tray, the vigil, the letters, the moon and the hour.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight + Theme.ribbonDrop + 8
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "grimoire-bar"
    exclusiveZone: Theme.barHeight
    mask: Region { item: plate; Region { item: ribbon } }

    // how much fits: 2 = everything, 1 = no date, 0 = portrait (no running head either)
    readonly property int tier: width >= 1700 ? 2 : width >= 1250 ? 1 : 0

    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "bar" && root.modelData === Quickshell.screens[0]) body.grabToImage(r => r.saveToFile(path)); }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // the page open on this screen
    readonly property var page: {
        const t = Hyprland.activeToplevel;
        return t && t.workspace?.id === monitor?.activeWorkspace?.id ? t : null;
    }
    readonly property string pageName: {
        if (!page) return "";
        const cls = page.lastIpcObject?.class ?? "";
        const app = cls ? (DesktopEntries.heuristicLookup(cls)?.name ?? cls) : "";
        const title = page.title ?? "";
        return app && title && !title.toLowerCase().includes(app.toLowerCase()) ? app + ", " + title : title || app;
    }

    Item {
        id: body
        anchors.fill: parent

        // ---------------------------------------------------------------- the leather strip
        Item {
            id: plate
            width: parent.width
            height: Theme.barHeight

            Leather { anchors.fill: parent; tooled: false; opacity_: 0.97 }
            // blind tooling: a sunken line along the strip, and the gilt edge at the foot
            Rectangle { y: 5; width: parent.width; height: 1; color: Qt.alpha("#000000", Theme.light ? 0.12 : 0.35) }
            Rectangle { y: 6; width: parent.width; height: 1; color: Theme.alpha(Theme.tooling, 0.5) }
            Rectangle { y: parent.height - 4; width: parent.width; height: 1; color: Theme.alpha(Theme.goldDeep, 0.9) }
            Rectangle { y: parent.height - 3; width: parent.width; height: 2; color: Theme.gold }
            Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Qt.alpha("#000000", 0.5) }
        }

        // ---------------------------------------------------------------- the clasp
        Item {
            id: clasp
            width: Theme.spineWidth
            height: Theme.barHeight
            Rectangle { anchors.right: parent.right; y: 9; width: 1; height: parent.height - 18; color: Qt.alpha("#000000", 0.35) }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: -1; y: 9; width: 1; height: parent.height - 18; color: Theme.alpha(Theme.tooling, 0.6) }

            Item {
                id: medal
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                width: 32; height: 32
                scale: claspMouse.pressed ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: claspMouse.containsMouse ? Theme.arcane : "#000000"
                    shadowBlur: claspMouse.containsMouse ? 0.8 : 0.4
                    shadowOpacity: claspMouse.containsMouse ? 0.9 : 0.6
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: claspMouse.containsMouse ? 0 : 2
                    blurMax: 16
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    border.width: 1
                    border.color: Theme.goldDeep
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.goldBright }
                        GradientStop { position: 0.5; color: Theme.gold }
                        GradientStop { position: 1; color: Theme.goldDeep }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha(Theme.goldDeep, 0.8)
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: "ᛟ"
                    color: claspMouse.containsMouse ? Theme.mix(Theme.arcane, Theme.leatherDark, 0.3) : Theme.leatherDark
                    font.family: Theme.runic
                    font.pixelSize: 17
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
            }
            MouseArea {
                id: claspMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => e.button === Qt.RightButton ? CodexState.toggleTo("helm") : ContentsState.toggle()
            }
        }

        // ---------------------------------------------------------------- the ribbon and the chapters
        Ribbon {
            id: ribbon
            x: chapters.x + chapters.ribbonX - width / 2
            y: 7
            length: Theme.barHeight + Theme.ribbonDrop - 7
            Behavior on x { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: OverviewState.toggle(); cursorShape: Qt.PointingHandCursor }
        }
        Chapters {
            id: chapters
            x: Theme.spineWidth + 10
            height: Theme.barHeight - 4
            monitor: root.monitor
            onTurned: dir => ribbon.swing(dir)
        }

        // ---------------------------------------------------------------- the running head
        Row {
            id: head
            visible: root.tier >= 1
            anchors.horizontalCenter: parent.horizontalCenter
            y: (Theme.barHeight - height) / 2 - 1
            width: Math.min(implicitWidth, right.x - (chapters.x + chapters.width) - 60)
            spacing: 10
            clip: true
            Caps {
                id: chapterName
                anchors.verticalCenter: parent.verticalCenter
                text: "Chapter " + Theme.roman(root.monitor?.activeWorkspace?.id ?? 1)
                color: Theme.alpha(Theme.gold, 0.85)
                font.pixelSize: 12
            }
            Text {
                visible: root.pageName !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: "❧"
                color: Theme.alpha(Theme.gold, 0.7)
                font.family: Theme.symbols
                font.pixelSize: 12
            }
            Body {
                visible: root.pageName !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Math.max(80, head.width - chapterName.width - 40))
                elide: Text.ElideRight
                text: root.pageName
                italic: true
                color: Theme.fg
                font.pixelSize: Theme.text
            }
        }

        // ---------------------------------------------------------------- the right-hand side
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 16
            height: Theme.barHeight - 4
            spacing: 16

            // a recording: the red scrying mark
            Readout {
                visible: Capture.recording
                onClicked: Capture.toggleRecording()
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10; radius: 5
                    color: Theme.danger
                    border.width: 1; border.color: Qt.lighter(Theme.danger, 1.4)
                    SequentialAnimation on opacity { running: Capture.recording; loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine } }
                }
                Body { anchors.verticalCenter: parent.verticalCenter; text: "scrying " + Capture.elapsedText; italic: true; color: Theme.danger }
            }
            // the scribe (dictation)
            Readout {
                visible: Voxtype.busy
                onClicked: Voxtype.toggle()
                Glyph { anchors.verticalCenter: parent.verticalCenter; text: "\u{f0d9a}"; color: Theme.arcane }
                Body { anchors.verticalCenter: parent.verticalCenter; italic: true; color: Theme.arcane
                       text: Voxtype.recording ? "the scribe listens " + Voxtype.elapsedText : "the scribe writes…" }
            }
            // the hourglass (focus timer)
            Readout {
                visible: FocusTimer.active
                onClicked: CodexState.toggleTo("chronometer")
                Text { anchors.verticalCenter: parent.verticalCenter; text: "⧗"; color: FocusTimer.running ? Theme.gold : Theme.dim
                       font.family: Theme.symbols; font.pixelSize: 16 }
                Body { anchors.verticalCenter: parent.verticalCenter; text: FocusTimer.remainingText; strong: true
                       color: FocusTimer.running ? Theme.goldBright : Theme.dim }
            }

            Tray { anchors.verticalCenter: parent.verticalCenter; bar: root }

            // the vigil (stay awake): an open eye while it keeps watch
            Readout {
                onClicked: StayAwake.on = !StayAwake.on
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: StayAwake.on ? "\u{f0208}" : "\u{f0209}"
                    color: StayAwake.on ? Theme.arcane : Theme.alpha(Theme.dim, 0.8)
                    font.pixelSize: 16
                }
            }

            // letters: a folded letter with a dab of wax while there are unread ones
            Readout {
                onClicked: CodexState.toggleTo("log")
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 14
                    Rectangle { anchors.fill: parent; radius: 1; color: Notifs.dnd ? Theme.alpha(Theme.dim, 0.35) : Theme.alpha(Theme.fg, 0.88) }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: -5; text: "⌄"; color: Theme.leather; font.pixelSize: 16; font.family: Theme.body }
                    Rectangle {
                        visible: Notifs.unread > 0 && !Notifs.dnd
                        anchors.centerIn: parent; anchors.verticalCenterOffset: 2
                        width: 8; height: 8; radius: 4
                        color: Theme.wax; border.width: 1; border.color: Qt.darker(Theme.wax, 1.4)
                    }
                    Text { visible: Notifs.dnd; anchors.centerIn: parent; text: "✕"; color: Theme.leather; font.pixelSize: 10 }
                }
                Body { visible: Notifs.unread > 0; anchors.verticalCenter: parent.verticalCenter; text: Notifs.unread; strong: true; color: Theme.gold }
            }

            // the moon and the hour
            Readout {
                onClicked: CodexState.toggleTo("almanac")
                spacing: 10
                Moon { anchors.verticalCenter: parent.verticalCenter; size: 15 }
                Body {
                    visible: root.tier >= 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(clock.date, "dddd") + ", the " + Theme.ordinal(clock.date.getDate()) + " of " + Qt.formatDate(clock.date, "MMMM")
                    italic: true
                    color: Theme.dim
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.date, "h:mm")
                    color: Theme.goldBright
                    font.family: Theme.uncial
                    font.pixelSize: 21
                    style: Text.Raised
                    styleColor: Qt.alpha("#000000", 0.5)
                }
            }
        }
    }

    // a readout: a row of pieces, clickable
    component Readout: Item {
        id: ro
        default property alias content: roRow.data
        property alias spacing: roRow.spacing
        signal clicked()
        width: roRow.width
        height: parent ? parent.height : Theme.barHeight
        Row { id: roRow; spacing: 6; height: parent.height }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ro.clicked() }
    }
}
