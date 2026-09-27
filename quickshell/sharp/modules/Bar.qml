import QtQuick
import Quickshell

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    // Auto-hide (OLED burn-in): the bar sits above the screen and slides down when the
    // cursor touches the top edge. Windows use the full height underneath it.
    exclusionMode: ExclusionMode.Ignore

    readonly property bool busy: media.open || claudePopout.open || trayPopout.open || panel.open
                                 || Capture.recording || Voxtype.busy
    readonly property bool shown: BarState.pinned || busy || hover.hovered || hideDelay.running

    // While hidden, only a thin strip along the top edge takes input
    mask: shown ? null : trigger
    Region { id: trigger; item: triggerStrip }
    Item {
        id: triggerStrip
        width: bar.width
        height: 2
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) hideDelay.restart()
    }

    // Grace period so a brief slip off the bar doesn't hide it
    Timer {
        id: hideDelay
        interval: 400
    }

    Item {
        id: content
        width: bar.width
        height: Theme.barHeight
        y: bar.shown ? 0 : -height
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.accent
        }

        // Overview toggle
        Rectangle {
            id: overviewButton

            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 30
            implicitHeight: Theme.barHeight - 10
            radius: 0
            color: OverviewState.open || overviewMouse.containsMouse ? Theme.surface : "transparent"
            border.width: OverviewState.open ? 1 : 0
            border.color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF0570)
                font.family: Theme.font
                font.pixelSize: 15
                color: OverviewState.open ? Theme.accent : Theme.dim
            }

            MouseArea {
                id: overviewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: OverviewState.toggle()
            }
        }

        Workspaces {
            anchors.left: overviewButton.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.screen
        }

        // One spectrum split around the clock: first half left, second half right
        Row {
            id: center
            anchors.centerIn: parent
            spacing: 16

            Visualizer {
                anchors.verticalCenter: parent.verticalCenter
                onClicked: media.open = !media.open
            }

            Clock {
                anchors.verticalCenter: parent.verticalCenter
                screen: bar.screen
            }

            Visualizer {
                anchors.verticalCenter: parent.verticalCenter
                start: Cava.bars / 2
                onClicked: media.open = !media.open
            }
        }

        Popout {
            id: media
            screen: bar.screen
            anchorItem: center

            MediaPanel {}
        }

        // Right side: focus timer, dictation, recording, tray, Tailscale, Claude Code, panel button
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Focus timer countdown; click to open the Focus tab
            BarPill {
                visible: FocusTimer.active
                tint: FocusTimer.mode === "pomodoro" && FocusTimer.phase !== "focus" ? Theme.green : Theme.accent
                icon: String.fromCodePoint(FocusTimer.mode === "pomodoro" ? 0xF051F : 0xF051B)
                text: FocusTimer.remainingText
                dim: !FocusTimer.running
                onClicked: bar.openPanel("Focus")
            }

            // Dictation (voxtype): click to finish recording, or to cancel a transcription
            BarPill {
                visible: Voxtype.busy
                tint: Voxtype.recording ? Theme.danger : Theme.accent
                pulse: Voxtype.recording
                icon: Voxtype.recording ? "" : String.fromCodePoint(0xF036C)
                text: Voxtype.recording ? "DICTATING " + Voxtype.elapsedText : "TRANSCRIBING"
                onClicked: Voxtype.recording ? Voxtype.toggle() : Voxtype.cancel()
            }

            // Recording; click to stop
            BarPill {
                visible: Capture.recording
                tint: Theme.danger
                pulse: true
                text: Capture.elapsedText
                onClicked: Capture.toggleRecording()
            }

            SysTray {
                anchors.verticalCenter: parent.verticalCenter
                openMenu: (item, anchor) => {
                    trayMenu.menu = item.menu;
                    trayMenu.title = item.tooltipTitle || item.title || item.id;
                    trayPopout.anchorItem = anchor;
                    trayPopout.open = true;
                }
            }

            // Tailscale status; click for its settings
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Net.tsAvailable
                implicitWidth: 30
                implicitHeight: Theme.barHeight - 10
                radius: 0
                color: tsMouse.containsMouse ? Theme.surface : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(Net.tsRunning ? 0xF0582 : 0xF0319)
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: Net.tsRunning ? (Net.tsExitNode ? Theme.green : Theme.accent) : Theme.border
                }

                MouseArea {
                    id: tsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.openPanel("Settings", 2)
                }
            }

            ClaudeButton {
                id: claudeButton
                anchors.verticalCenter: parent.verticalCenter
                active: claudePopout.open
                onInfoRequested: {
                    ClaudeStatus.refreshIfStale();
                    claudePopout.open = true;
                }
            }

            PanelButton {
                anchors.verticalCenter: parent.verticalCenter
                active: panel.open
                onClicked: panel.open = !panel.open
            }
        }
    }

    function openPanel(tab, subPage) {
        controlPanel.show(tab, subPage);
        panel.open = true;
    }

    Popout {
        id: claudePopout
        screen: bar.screen
        anchorItem: claudeButton

        ClaudeInfo {
            onLaunchRequested: {
                claudePopout.open = false;
                ClaudeStatus.launch();
            }
        }
    }

    Popout {
        id: trayPopout
        screen: bar.screen

        TrayMenu {
            id: trayMenu
            onDone: trayPopout.open = false
        }
    }

    Popout {
        id: panel
        screen: bar.screen
        side: "right"
        onOpened: {
            Notifs.unread = false;
            Weather.refreshIfStale();
        }
        // Don't leave the mic test running once the panel is gone
        onOpenChanged: if (!open) Cava.source = ""

        ControlPanel {
            id: controlPanel
            onCloseRequested: panel.open = false
            width: 400
            // Fill the screen height below the bar
            height: panel.height - Theme.barHeight - 18 - 44
        }
    }
}
