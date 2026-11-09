import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The polkit agent (an app asks for admin rights): a card in the middle of a dimmed screen, like the
// lock's: the ring, what's being asked, the password pill with the red caret, cancel / allow.
Scope {
    id: root

    PolkitAgent { id: agent }
    readonly property var flow: agent.flow
    readonly property bool open: agent.isActive && flow !== null

    function authorise() { if (flow?.isResponseRequired) flow.submit(field.text); }
    function cancel() { flow?.cancelAuthenticationRequest(); }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        readonly property real s: Theme.scaleFor(screen)
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) field.focusField()
        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.focusField(); } }
        }

        Rectangle { anchors.fill: parent; color: Theme.scrim }
        MouseArea { anchors.fill: parent }

        Stage {
            id: stage
            s: win.s
            Rectangle {
                anchors.centerIn: parent
                width: 600
                height: body.implicitHeight + 68
                radius: 44
                color: Theme.s1
                border { width: 1; color: root.flow?.supplementaryIsError ? Theme.red : Theme.s2 }

                Column {
                    id: body
                    x: 34
                    y: 34
                    width: parent.width - 68
                    spacing: 18
                    Row {
                        spacing: 18
                        Item {
                            width: 64
                            height: 64
                            Ring { anchors.fill: parent; n: 24; dot: 4 }
                            Icon { anchors.centerIn: parent; text: "\u{F0483}"; font.pixelSize: 24 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Lb { text: "authentication"; color: Theme.fg }
                            Lb { text: "as " + (Quickshell.env("USER") ?? "") }
                        }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.flow?.message ?? ""
                        color: Theme.fg
                        font { family: Theme.ui; pixelSize: 18 }
                        lineHeight: 1.15
                    }
                    Field {
                        id: field
                        width: parent.width
                        height: 58
                        glyph: "\u{F0306}"
                        password: !(root.flow?.responseVisible ?? false)
                        enabled: root.flow?.isResponseRequired ?? false
                        placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                        onAccepted: root.authorise()
                        input.Keys.onEscapePressed: root.cancel()
                    }
                    Lb {
                        visible: text !== ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: root.flow?.supplementaryMessage ?? ""
                        color: root.flow?.supplementaryIsError ? Theme.red : Theme.grey
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 10
                        Btn { text: "cancel"; onClicked: root.cancel() }
                        Btn { text: "allow"; on: true; onClicked: root.authorise() }
                    }
                }
            }
        }
    }
}
