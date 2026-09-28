import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The polkit agent (admin password prompts for pkexec, disk tools, installers…) as Windows'
// User Account Control: the screen dims, and the dialog asks "Do you want to allow this app to make
// changes to your device?" with the program's message, your name and a password box; Yes / No.
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
        WlrLayershell.namespace: "disguise-uac"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) field.focusField()
        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.focusField(); } }
        }

        // the secure desktop: everything dimmed
        Rectangle { anchors.fill: parent; color: Qt.alpha("#000000", 0.55) }
        MouseArea { anchors.fill: parent }

        Item {
            id: dlg
            anchors.centerIn: parent
            width: 456
            height: top.height + bottom.height
            Acrylic { anchors.fill: parent; tint: Theme.mica; tintAlpha: 0.98 }

            Column {
                id: top
                width: parent.width
                padding: 24
                spacing: 14
                Txt { text: "User Account Control"; size: Theme.caption }
                Txt {
                    width: parent.width - 48
                    text: "Do you want to allow this app to make changes to your device?"
                    size: Theme.subtitle; strong: true
                    wrapMode: Text.Wrap; elide: Text.ElideNone
                }
                Row {
                    spacing: 14
                    AppIcon {
                        size: 32
                        name: (root.flow?.iconName ?? "") !== "" && Quickshell.hasThemeIcon(root.flow.iconName) ? root.flow.iconName : "dialog-password"
                    }
                    Column {
                        Txt { text: root.flow?.actionId?.split(".").slice(-2).join(" ") || "Administrative task"; strong: true }
                        Txt { text: "Verified publisher: polkit"; size: Theme.caption; level: 2 }
                    }
                }
                Txt { width: parent.width - 48; text: root.flow?.message ?? ""; wrapMode: Text.Wrap; elide: Text.ElideNone; level: 2 }
                Txt { text: "To continue, enter your password."; }
                Row {
                    spacing: 12
                    Avatar { size: 32; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 6
                        Txt { text: Quickshell.env("USER") ?? ""; strong: true }
                        Field {
                            id: field
                            width: 330
                            placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                            password: !(root.flow?.responseVisible ?? false)
                            enabled: root.flow?.isResponseRequired ?? false
                            onAccepted: root.authorise()
                            input.Keys.onEscapePressed: root.cancel()
                        }
                    }
                }
                Txt {
                    visible: text !== ""
                    width: parent.width - 48
                    wrapMode: Text.Wrap
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.danger : Theme.text2
                }
            }
            Item {
                id: bottom
                y: top.height
                width: parent.width
                height: 80
                Rectangle {
                    anchors.fill: parent; anchors.margins: 1
                    color: Theme.dark ? Qt.alpha("#000000", 0.2) : Qt.alpha("#000000", 0.035)
                    bottomLeftRadius: Theme.radiusLarge; bottomRightRadius: Theme.radiusLarge
                }
                Rectangle { width: parent.width; height: 1; color: Theme.divider }
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Btn { kind: "accent"; width: 196; text: "Yes"; onClicked: root.authorise() }
                    Btn { width: 196; text: "No"; onClicked: root.cancel() }
                }
            }
        }
    }
}
