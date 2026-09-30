import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The polkit agent (admin passwords for pkexec, disk tools, installers…): "A Seal is Required", a
// sheet of parchment over the darkened desk, headed by an illuminated A, saying what asks and why;
// the word goes on an inked line; a wrong word says so and asks again. Grant or refuse; Esc refuses.
Scope {
    id: root

    PolkitAgent { id: agent }
    readonly property var flow: agent.flow
    readonly property bool open: agent.isActive && flow !== null

    function grant() { if (flow?.isResponseRequired) flow.submit(field.text); }
    function refuse() { flow?.cancelAuthenticationRequest(); }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "grimoire-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) field.focusField()
        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.focusField(); } }
        }

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.veil, 0.72) }
        MouseArea { anchors.fill: parent }

        Item {
            anchors.centerIn: parent
            width: 540
            height: body.implicitHeight + 50

            Rectangle {
                anchors.fill: parent; anchors.topMargin: 12; anchors.leftMargin: 8; anchors.rightMargin: -8; anchors.bottomMargin: -14
                radius: 4; color: Qt.alpha("#000000", 0.55)
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 32 }
            }
            Parchment { anchors.fill: parent; age: 0.55 }
            Repeater {
                model: ["tl", "tr", "bl", "br"]
                Flourish { required property string modelData; corner: modelData; size: 40; color: Theme.goldDeep; shade: "transparent"; stroke: 1.2
                           x: modelData.endsWith("l") ? 8 : parent.width - 48; y: modelData.startsWith("t") ? 8 : parent.height - 48 }
            }
            Column {
                id: body
                x: 36; y: 26
                width: parent.width - 72
                spacing: 14
                Row {
                    spacing: 14
                    Initial { letter: "A"; size: 50 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Seal is Required"; color: Theme.ink; font.family: Theme.display; font.weight: Font.DemiBold; font.pixelSize: 26 }
                        Body { text: "something asks for the keeper's authority"; italic: true; color: Theme.inkDim; font.pixelSize: 14 }
                    }
                }
                GoldRule { width: parent.width; color: Theme.alpha(Theme.inkDim, 0.6); ornament: "❦" }
                Body { width: parent.width; wrapMode: Text.Wrap; text: root.flow?.message ?? ""; font.pixelSize: 16 }
                Body { text: "speak for " + (Quickshell.env("USER") ?? "yourself"); italic: true; color: Theme.inkDim; font.pixelSize: 14 }
                Field {
                    id: field
                    width: parent.width
                    height: 36
                    password: !(root.flow?.responseVisible ?? false)
                    enabled: root.flow?.isResponseRequired ?? false
                    placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "the word"
                    onAccepted: root.grant()
                    input.Keys.onEscapePressed: root.refuse()
                }
                Body {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow?.supplementaryIsError ? "The word is not known. " + (root.flow?.supplementaryMessage ?? "") : root.flow?.supplementaryMessage ?? ""
                    italic: true
                    color: root.flow?.supplementaryIsError ? Theme.rubric : Theme.inkDim
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Btn { text: "refuse"; onClicked: root.refuse() }
                    Btn { text: "grant"; primary: true; onClicked: root.grant() }
                }
            }
        }
    }
}
