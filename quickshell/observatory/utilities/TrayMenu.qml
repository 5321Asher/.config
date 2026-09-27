import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../theme"

// A tray app's menu, as a brass plate dropping from its icon on the horizon. Submenus open in
// place with a back row. Click outside or Esc closes it.
PanelWindow {
    id: root

    screen: TrayMenuState.screen ?? Quickshell.screens[0]
    visible: TrayMenuState.item !== null || plate.opacity > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-traymenu"
    WlrLayershell.keyboardFocus: TrayMenuState.item ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: TrayMenuState.item ? null : noInput
    Region { id: noInput }

    property var stack: []          // submenu handles, innermost last
    readonly property var current: stack.length ? stack[stack.length - 1] : TrayMenuState.item?.menu ?? null
    Connections {
        target: TrayMenuState
        function onItemChanged() { root.stack = []; if (TrayMenuState.item) keys.forceActiveFocus(); }
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: TrayMenuState.close()

        MouseArea { anchors.fill: parent; onClicked: TrayMenuState.close() }

        Item {
            id: plate
            readonly property real localX: TrayMenuState.anchorX
            width: Theme.trayMenuWidth
            height: col.implicitHeight + 20
            x: Math.max(8, Math.min(root.width - width - 8, localX - width / 2))
            y: Theme.deckTop
            opacity: TrayMenuState.item ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
            transform: Translate { y: (1 - plate.opacity) * -8 }

            MouseArea { anchors.fill: parent }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1
                    strokeColor: Theme.alpha(Theme.brass, 0.85)
                    fillColor: Theme.alpha(Theme.bgDark, 0.95)
                    startX: Theme.chamfer; startY: 0.5
                    PathLine { x: plate.width - Theme.chamfer; y: 0.5 }
                    PathLine { x: plate.width - 0.5; y: Theme.chamfer }
                    PathLine { x: plate.width - 0.5; y: plate.height - 0.5 }
                    PathLine { x: 0.5; y: plate.height - 0.5 }
                    PathLine { x: 0.5; y: Theme.chamfer }
                    PathLine { x: Theme.chamfer; y: 0.5 }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 0.8; shadowOpacity: 0.5
                    shadowVerticalOffset: 4; blurMax: 24
                }
            }

            Column {
                id: col
                x: 8; y: 10
                width: parent.width - 16
                spacing: 1

                Text {
                    x: 8
                    width: parent.width - 16
                    visible: root.stack.length === 0
                    elide: Text.ElideRight
                    text: (TrayMenuState.item?.tooltipTitle || TrayMenuState.item?.title || TrayMenuState.item?.id || "").toLowerCase()
                    color: Theme.brass
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                    bottomPadding: 4
                }

                Entry {
                    visible: root.stack.length > 0
                    text: "back"
                    glyph: "\u{f0141}"
                    onClicked: root.stack = root.stack.slice(0, -1)
                }

                Repeater {
                    model: opener.children
                    Loader {
                        id: loader
                        required property var modelData
                        width: col.width
                        sourceComponent: modelData.isSeparator ? separator : entry
                        Component {
                            id: separator
                            Item {
                                height: 9
                                Rectangle { anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.alpha(Theme.brass, 0.2) }
                            }
                        }
                        Component {
                            id: entry
                            Entry {
                                readonly property var e: loader.modelData
                                text: e.text.replace(/_(?=\S)/, "")
                                iconSource: e.icon
                                enabled: e.enabled
                                check: e.buttonType === QsMenuButtonType.CheckBox ? (e.checkState === Qt.Checked ? "on" : "off")
                                     : e.buttonType === QsMenuButtonType.RadioButton ? (e.checkState === Qt.Checked ? "radio-on" : "radio-off")
                                     : ""
                                submenu: e.hasChildren
                                onClicked: {
                                    if (e.hasChildren) root.stack = root.stack.concat([e]);
                                    else { e.triggered(); TrayMenuState.close(); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Entry: Item {
        id: en
        property string text
        property string glyph
        property string iconSource
        property string check
        property bool submenu
        signal clicked()
        width: parent ? parent.width : 200
        height: 30
        opacity: enabled ? 1 : 0.4
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: enMouse.containsMouse && en.enabled ? Theme.alpha(Theme.brassMuted, 0.6) : "transparent"
        }
        Item {
            id: lead
            x: 8
            width: 16
            height: parent.height
            Text {
                anchors.centerIn: parent
                visible: en.check !== "" || en.glyph !== ""
                text: en.glyph !== "" ? en.glyph
                    : String.fromCodePoint({ "on": 0xF0C52, "off": 0xF0131, "radio-on": 0xF043E, "radio-off": 0xF043D }[en.check] ?? 0x20)
                color: en.check === "on" || en.check === "radio-on" ? Theme.brassBright : Theme.dim
                font.family: Theme.fontData
                font.pixelSize: 14
            }
            Image {
                anchors.centerIn: parent
                visible: en.check === "" && en.glyph === "" && en.iconSource !== ""
                source: en.iconSource
                sourceSize.width: 16
                sourceSize.height: 16
            }
        }
        Text {
            anchors.left: lead.right
            anchors.leftMargin: 10
            anchors.right: chev.left
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: en.text
            color: enMouse.containsMouse ? Theme.starlight : Theme.fg
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSize
        }
        Text {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: en.submenu
            text: "\u{f0142}"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: 14
        }
        MouseArea {
            id: enMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: en.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (en.enabled) en.clicked()
        }
    }
}
