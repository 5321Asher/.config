import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "pages"

// The control deck: a brass-framed panel that slides in from the right of the focused monitor, with
// a rail of instrument knobs for its pages (DeckState.pages). Esc or a click outside closes it.
// Opened from the deck knob and gauges on the horizon, the sundial (almanac), or:
//   qs ipc call deck open <page>
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: DeckState.open || shown > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "observatory-deck"
    WlrLayershell.keyboardFocus: DeckState.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: DeckState.open ? null : noInput
    Region { id: noInput }

    property real shown: DeckState.open ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.slow; easing.type: Theme.easing } }

    onVisibleChanged: if (visible) keys.forceActiveFocus()

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: DeckState.open = false

        MouseArea {
            anchors.fill: parent
            onClicked: DeckState.open = false
        }

        Item {
            id: plate
            width: Theme.deckWidth
            height: root.height - Theme.deckTop - Theme.deckBottom
            x: root.width - width - Theme.deckRight + (1 - root.shown) * 70
            y: Theme.deckTop
            opacity: root.shown

            MouseArea { anchors.fill: parent }     // clicks on the plate don't close it

            // Frame: corners cut, brass hairline, a brighter rule down the rail
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.2
                    strokeColor: Theme.alpha(Theme.brass, 0.85)
                    fillColor: Theme.alpha(Theme.bgDark, 0.94)
                    startX: Theme.chamfer * 1.5; startY: 0.5
                    PathLine { x: plate.width - 0.5; y: 0.5 }
                    PathLine { x: plate.width - 0.5; y: plate.height - Theme.chamfer * 1.5 }
                    PathLine { x: plate.width - Theme.chamfer * 1.5; y: plate.height - 0.5 }
                    PathLine { x: 0.5; y: plate.height - 0.5 }
                    PathLine { x: 0.5; y: Theme.chamfer * 1.5 }
                    PathLine { x: Theme.chamfer * 1.5; y: 0.5 }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1; shadowOpacity: 0.6
                    shadowHorizontalOffset: -6; shadowVerticalOffset: 6; blurMax: 32
                }
            }
            Rectangle {
                x: Theme.deckRail
                y: 14
                width: 1
                height: parent.height - 28
                color: Theme.alpha(Theme.brass, 0.3)
            }

            // Rail: one knob per page
            Column {
                id: rail
                x: (Theme.deckRail - Theme.deckRailKnob) / 2
                y: 18
                spacing: 10
                Repeater {
                    model: DeckState.pages
                    Knob {
                        id: railKnob
                        required property var modelData
                        size: Theme.deckRailKnob
                        glyph: modelData.glyph
                        active: DeckState.page === modelData.id
                        onClicked: DeckState.page = modelData.id
                        ToolTipLabel { text: railKnob.modelData.title; target: railKnob }
                    }
                }
            }

            // Header
            Column {
                id: header
                x: Theme.deckRail + 20
                y: 16
                width: parent.width - x - 20
                spacing: 0
                Text {
                    text: DeckState.current.title
                    color: Theme.brassBright
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge + 10
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing * 2
                    font.weight: Font.DemiBold
                }
                Text {
                    text: DeckState.current.sub
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
            Rectangle {
                x: header.x
                y: header.y + header.height + 10
                width: header.width
                height: 1
                color: Theme.alpha(Theme.brass, 0.35)
            }

            // The page
            Flickable {
                id: flick
                x: header.x
                y: header.y + header.height + 24
                width: header.width
                height: parent.height - y - 16
                clip: true
                contentHeight: loader.item ? loader.item.implicitHeight + 8 : 0
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: loader
                    width: flick.width
                    active: root.visible
                    sourceComponent: pageComponents[DeckState.current.file] ?? null
                    opacity: 0
                    onLoaded: { flick.contentY = 0; arrive.restart(); }
                    NumberAnimation on opacity { id: arrive; from: 0; to: 1; duration: Theme.normal; easing.type: Theme.easing; running: false }
                }
            }
            // scroll position, as a thin brass tick on the right edge
            Rectangle {
                visible: flick.contentHeight > flick.height
                x: parent.width - 6
                y: flick.y + flick.visibleArea.yPosition * flick.height
                width: 2
                height: Math.max(20, flick.visibleArea.heightRatio * flick.height)
                radius: 1
                color: Theme.alpha(Theme.brass, 0.6)
            }
        }
    }

    // Pages as types (not file paths), so live reload tracks them; each is only created when shown
    readonly property var pageComponents: ({
        Helm: helmPage, Media: mediaPage, Log: logPage, Almanac: almanacPage, Telemetry: telemetryPage,
        Hangar: hangarPage, Optics: opticsPage, Lamps: lampsPage, Chronometer: chronometerPage,
        Comms: commsPage, Claude: claudePage,
    })
    Component { id: helmPage; Helm {} }
    Component { id: mediaPage; Media {} }
    Component { id: logPage; Log {} }
    Component { id: almanacPage; Almanac {} }
    Component { id: telemetryPage; Telemetry {} }
    Component { id: hangarPage; Hangar {} }
    Component { id: opticsPage; Optics {} }
    Component { id: lampsPage; Lamps {} }
    Component { id: chronometerPage; Chronometer {} }
    Component { id: commsPage; Comms {} }
    Component { id: claudePage; Claude {} }

    // Hover label for a rail knob: a small brass tag outside the plate, to its left, with a hairline
    // to the knob (inside the plate it covered the page title)
    component ToolTipLabel: Item {
        id: tag
        property Item target
        property alias text: label.text
        parent: plate
        z: 10
        readonly property bool shown: target ? target.hovered : false
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
        width: label.implicitWidth + 24
        height: label.implicitHeight + 8
        x: -width - Theme.deckTagGap + (shown ? 0 : 6)
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
        y: target ? rail.y + target.y + (Theme.deckRailKnob - height) / 2 : 0     // knobs sit in the rail column

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Theme.alpha(Theme.bgDark, 0.94)
            border.width: 1
            border.color: Theme.alpha(Theme.brass, 0.8)
        }
        // hairline from the tag, across the gap, to the knob
        Rectangle {
            x: parent.width
            y: parent.height / 2
            width: Theme.deckTagGap + (Theme.deckRail - Theme.deckRailKnob) / 2
            height: 1
            color: Theme.alpha(Theme.brass, 0.6)
        }
        Text {
            id: label
            anchors.centerIn: parent
            color: Theme.brassBright
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
        }
    }
}
