import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Widgets

// Polkit authentication agent: asks for the admin password when an app needs it (pkexec, disk
// tools, installers). Flat card on the focused monitor; Enter authenticates, Esc cancels.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    readonly property bool open: agent.isActive && flow !== null

    function authenticate() {
        if (flow?.isResponseRequired) flow.submit(field.text);
    }
    function cancel() {
        flow?.cancelAuthenticationRequest();
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open || shade.opacity > 0.01
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) field.forceActiveFocus()
        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.forceActiveFocus(); } }
        }

        Rectangle {
            id: shade
            anchors.fill: parent
            color: Qt.rgba(Theme.bgDark.r, Theme.bgDark.g, Theme.bgDark.b, 0.75)
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea { anchors.fill: parent }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 440
            height: col.implicitHeight + 36
            opacity: shade.opacity
            color: Theme.bg
            border.width: 1
            border.color: root.flow?.supplementaryIsError ? Theme.danger : Theme.accent

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 2
                color: root.flow?.supplementaryIsError ? Theme.danger : Theme.accent
            }

            Column {
                id: col
                x: 18
                y: 18
                width: parent.width - 36
                spacing: 12

                Text {
                    text: "AUTHENTICATION REQUIRED"
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    font.letterSpacing: 2
                    color: Theme.accent
                }
                Row {
                    width: parent.width
                    spacing: 12
                    IconImage {
                        id: icon
                        readonly property string ic: root.flow?.iconName ?? ""
                        visible: ic !== "" && Quickshell.hasThemeIcon(ic)
                        implicitSize: visible ? 32 : 0
                        source: visible ? Quickshell.iconPath(ic) : ""
                    }
                    Text {
                        width: parent.width - (icon.visible ? 44 : 0)
                        wrapMode: Text.Wrap
                        text: root.flow?.message ?? ""
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.fg
                    }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: root.flow?.actionId ?? ""
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.dim
                }
                Rectangle {
                    width: parent.width
                    height: 34
                    color: Theme.bgDark
                    border.width: 1
                    border.color: field.activeFocus ? Theme.accent : Theme.border
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.dim
                    }
                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 13
                        enabled: root.flow?.isResponseRequired ?? false
                        Keys.onReturnPressed: root.authenticate()
                        Keys.onEnterPressed: root.authenticate()
                        Keys.onEscapePressed: root.cancel()
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: root.flow?.supplementaryIsError ? Theme.danger : Theme.dim
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Repeater {
                        model: [{ label: "Cancel", primary: false }, { label: "Authenticate", primary: true }]
                        Rectangle {
                            required property var modelData
                            width: label.implicitWidth + 24
                            height: 30
                            color: modelData.primary ? (btn.containsMouse ? Theme.accentMuted : Theme.surface) : (btn.containsMouse ? Theme.hover : "transparent")
                            border.width: 1
                            border.color: modelData.primary ? Theme.accent : Theme.border
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: parent.modelData.primary
                                color: parent.modelData.primary ? Theme.accent : Theme.fg
                            }
                            MouseArea {
                                id: btn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.modelData.primary ? root.authenticate() : root.cancel()
                            }
                        }
                    }
                }
            }
        }
    }
}
