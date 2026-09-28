import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The polkit agent (admin password prompts for pkexec, disk tools, installers…), as a 98 dialog
// over a dithered screen, the way 98's Shut Down box dimmed everything behind it: the program's
// message, your user name, a password box, OK / Cancel. A wrong password says so and asks again.
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
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "memphis-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) field.focusField()
        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.focusField(); } }
        }

        // 98's "shutting down" dither over everything
        Dither { anchors.fill: parent; a: "#000000"; b: "transparent"; opacity: 0.5 }
        MouseArea { anchors.fill: parent }

        Win {
            anchors.centerIn: parent
            width: 520
            height: Math.max(250, body.implicitHeight + Theme.titleHeight + 70)
            title: "Authentication Required"
            onCloseRequested: root.cancel()
            Keys.onEscapePressed: root.cancel()

            Icon {
                x: 14; y: 14
                name: (root.flow?.iconName ?? "") !== "" && Quickshell.hasThemeIcon(root.flow.iconName) ? root.flow.iconName : "dialog-password"
                fallback: "system-lock-screen"
                size: 48
            }
            Column {
                id: body
                x: 80; y: 12
                width: parent.width - 96
                spacing: 10
                Txt { width: parent.width; wrapMode: Text.Wrap; verticalAlignment: Text.AlignTop; text: root.flow?.message ?? "" }
                Row {
                    spacing: 8
                    Txt { width: 110; height: Theme.field; text: "User name:" }
                    Field { width: 220; readOnly: true; text: Quickshell.env("USER") ?? "" }
                }
                Row {
                    spacing: 8
                    Txt { width: 110; height: Theme.field; text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") + ":" || "Password:" }
                    Field {
                        id: field
                        width: 220
                        password: !(root.flow?.responseVisible ?? false)
                        enabled: root.flow?.isResponseRequired ?? false
                        onAccepted: root.authorise()
                        input.Keys.onEscapePressed: root.cancel()
                    }
                }
                Txt {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.danger : Theme.text
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                spacing: 8
                Btn { text: "OK"; isDefault: true; onClicked: root.authorise() }
                Btn { text: "Cancel"; onClicked: root.cancel() }
            }
        }
    }
}
