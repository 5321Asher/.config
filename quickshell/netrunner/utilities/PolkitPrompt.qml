import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The polkit agent (admin passwords for pkexec, disk tools, installers…): ROOT ACCESS 管理者 over
// a darkened screen: what's asking and why, the passphrase, AUTHORISE / ABORT. A wrong
// passphrase says so and asks again. Esc aborts.
Scope {
    id: root

    PolkitAgent { id: agent }
    readonly property var flow: agent.flow
    readonly property bool open: agent.isActive && flow !== null

    function authorise() { if (flow?.isResponseRequired) flow.submit(field.text); }
    function cancel() { flow?.cancelAuthenticationRequest(); }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "netrunner-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) field.focusField()
        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.focusField(); } }
        }

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.7) }
        MouseArea { anchors.fill: parent }

        Item {
            anchors.centerIn: parent
            width: 540
            height: body.implicitHeight + 40

            Chamfer { anchors.fill: parent; cut: 16; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.96)
                      stroke: root.flow?.supplementaryIsError ? Theme.red : Theme.alpha(Theme.red, 0.7) }
            Hazard { x: parent.width - 110; y: 0; width: 90; height: 6 }
            Column {
                id: body
                x: 22; y: 20
                width: parent.width - 44
                spacing: 12
                Row {
                    spacing: 10
                    Tag { anchors.verticalCenter: parent.verticalCenter; text: "ROOT ACCESS"; height: 22 }
                    Jp { anchors.verticalCenter: parent.verticalCenter; text: "管理者認証" }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; text: root.flow?.message ?? ""; color: Theme.bright
                       font.family: Theme.sans; font.pixelSize: Theme.data + 1 }
                Label { text: "OPERATOR  //  " + (Quickshell.env("USER") ?? "") }
                Field {
                    id: field
                    width: parent.width
                    height: 36
                    password: !(root.flow?.responseVisible ?? false)
                    enabled: root.flow?.isResponseRequired ?? false
                    placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "passphrase"
                    onAccepted: root.authorise()
                    input.Keys.onEscapePressed: root.cancel()
                }
                Label {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.red : Theme.dim
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Btn { text: "abort"; onClicked: root.cancel() }
                    Btn { text: "authorise"; primary: true; onClicked: root.authorise() }
                }
            }
        }
    }
}
