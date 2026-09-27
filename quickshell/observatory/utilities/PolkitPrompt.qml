import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"

// Polkit authentication agent: when an app needs admin rights (pkexec, disk tools, installers…)
// this asks for the password, as a clearance request on the focused monitor. Enter authorises,
// Esc cancels. A wrong password says so and asks again.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    readonly property bool open: agent.isActive && flow !== null

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open || shade.opacity > 0.01
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "observatory-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) field.forceActiveFocus()
        Connections {
            target: root.flow
            function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.forceActiveFocus(); } }
        }

        Rectangle {
            id: shade
            anchors.fill: parent
            color: Theme.alpha(Theme.bgDark, 0.7)
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Theme.easing } }
            MouseArea { anchors.fill: parent }      // modal
        }

        Item {
            id: plate
            anchors.centerIn: parent
            width: Theme.polkitWidth
            height: body.implicitHeight + 2 * Theme.transmissionPad + 8
            opacity: shade.opacity
            scale: 0.96 + 0.04 * shade.opacity

            // shake on a wrong password
            property real shake: 0
            transform: Translate { x: plate.shake }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: plate; property: "shake"; to: -12; duration: 50 }
                NumberAnimation { target: plate; property: "shake"; to: 9; duration: 70 }
                NumberAnimation { target: plate; property: "shake"; to: -5; duration: 70 }
                NumberAnimation { target: plate; property: "shake"; to: 0; duration: 60 }
            }
            Connections {
                target: root.flow
                function onSupplementaryMessageChanged() { if (root.flow?.supplementaryIsError) shakeAnim.restart(); }
                function onFailedChanged() { if (root.flow?.failed) shakeAnim.restart(); }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.2
                    strokeColor: root.flow?.supplementaryIsError ? Theme.signal : Theme.brass
                    fillColor: Theme.alpha(Theme.bgDark, 0.96)
                    startX: Theme.chamfer; startY: 0.5
                    PathLine { x: plate.width - Theme.chamfer; y: 0.5 }
                    PathLine { x: plate.width - 0.5; y: Theme.chamfer }
                    PathLine { x: plate.width - 0.5; y: plate.height - Theme.chamfer }
                    PathLine { x: plate.width - Theme.chamfer; y: plate.height - 0.5 }
                    PathLine { x: Theme.chamfer; y: plate.height - 0.5 }
                    PathLine { x: 0.5; y: plate.height - Theme.chamfer }
                    PathLine { x: 0.5; y: Theme.chamfer }
                    PathLine { x: Theme.chamfer; y: 0.5 }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.7; shadowOpacity: 0.5
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 28
                }
            }

            Column {
                id: body
                x: Theme.transmissionPad + 6
                y: Theme.transmissionPad + 4
                width: parent.width - 2 * (Theme.transmissionPad + 6)
                spacing: 10

                Row {
                    spacing: 10
                    Rectangle {
                        width: 8; height: 8; rotation: 45
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.warn
                    }
                    Text {
                        text: "clearance required"
                        color: Theme.brass
                        font.family: Theme.fontLabel
                        font.pixelSize: Theme.labelSizeLarge
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: Theme.labelSpacing * 1.5
                        font.weight: Font.DemiBold
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.brass, 0.3) }

                Row {
                    width: parent.width
                    spacing: 12
                    IconImage {
                        id: icon
                        readonly property string ic: root.flow?.iconName ?? ""
                        visible: ic !== "" && Quickshell.hasThemeIcon(ic)
                        implicitSize: visible ? 36 : 0
                        source: visible ? Quickshell.iconPath(ic) : ""
                    }
                    Text {
                        width: parent.width - (icon.visible ? 48 : 0)
                        wrapMode: Text.Wrap
                        text: root.flow?.message ?? ""
                        color: Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize
                    }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: root.flow?.actionId ?? ""
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }

                // Password
                Item {
                    width: parent.width
                    height: 38
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Theme.alpha(Theme.bg, 0.9)
                        border.width: field.activeFocus ? 1.4 : 1
                        border.color: root.flow?.supplementaryIsError ? Theme.signal : field.activeFocus ? Theme.brassBright : Theme.border
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "").toLowerCase() || "password"
                        color: Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize
                    }
                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.phosphor
                        selectionColor: Theme.brassMuted
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize + 2
                        font.letterSpacing: 2
                        enabled: root.flow?.isResponseRequired ?? false
                        Keys.onReturnPressed: root.authorise()
                        Keys.onEnterPressed: root.authorise()
                        Keys.onEscapePressed: root.cancel()
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.signal : Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall + 1
                }

                Row {
                    anchors.right: parent.right
                    spacing: 22
                    Repeater {
                        model: [{ label: "cancel", act: () => root.cancel() }, { label: "authorise", act: () => root.authorise() }]
                        Text {
                            required property var modelData
                            required property int index
                            text: modelData.label
                            color: btn.containsMouse ? Theme.brassBright : index === 1 ? Theme.brass : Theme.dim
                            font.family: Theme.fontLabel
                            font.pixelSize: Theme.labelSizeLarge
                            font.capitalization: Font.SmallCaps
                            font.letterSpacing: Theme.labelSpacing
                            font.weight: Font.DemiBold
                            MouseArea {
                                id: btn
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.modelData.act()
                            }
                        }
                    }
                }
            }
        }
    }

    function authorise() {
        if (flow?.isResponseRequired) flow.submit(field.text);
    }
    function cancel() {
        flow?.cancelAuthenticationRequest();
    }
}
