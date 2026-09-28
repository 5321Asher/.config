import QtQuick
import Quickshell
import "../theme"

// A 98 push button: raised, pushed in while held (its label shifts a pixel down-right), a dotted
// focus rectangle, a black outline when it's the dialog's default button. `checked` holds it in
// with a dithered face (toggle buttons, the active window's taskbar button).
// `flat`: a toolbar button, no edge until the pointer is over it.
Item {
    id: root

    property string text: ""
    property string icon: ""            // theme icon name
    property string glyph: ""           // Glyph kind (caption buttons, arrows)
    property int iconSize: Theme.icon
    property bool bold: false
    property bool checked: false
    property bool isDefault: false
    property bool flat: false
    property bool dither: checked       // the checkerboard face when held in
    property int align: Qt.AlignHCenter
    property int padding: 10
    property alias hovered: mouse.containsMouse
    readonly property bool down: (mouse.pressed && mouse.containsMouse) || checked
    default property alias extra: slot.data

    signal clicked()
    signal rightClicked()

    // natural width from the label's own size (the row's is clipped to the button)
    TextMetrics { id: tm; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: root.bold; text: root.text }
    readonly property real naturalWidth: (text ? Math.ceil(tm.advanceWidth) + 2 : 0) + (icon ? iconSize + 6 : 0)
        + (glyph ? 16 : 0) + (slot.width > 0 ? slot.width + 6 : 0)
    implicitWidth: Math.max(Theme.buttonWidth, naturalWidth + padding * 2)
    implicitHeight: Theme.button
    activeFocusOnTab: true

    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()

    // default button: 1 px black outline round the whole thing
    Rectangle {
        anchors.fill: parent
        visible: root.isDefault && !root.flat
        color: "transparent"
        border.width: 1
        border.color: Theme.dkShadow
    }
    Bevel {
        id: edge
        anchors.fill: parent
        anchors.margins: root.isDefault && !root.flat ? 1 : 0
        kind: root.flat ? (root.down ? "status" : mouse.containsMouse && root.enabled ? "thin" : "none")
            : root.down ? (root.isDefault ? "status" : "pressed") : "button"
        fill: Theme.face
    }
    Dither {
        anchors.fill: parent
        anchors.margins: 2
        visible: root.dither && root.checked
    }

    Row {
        id: row
        spacing: 6
        x: root.align === Qt.AlignLeft ? root.padding : (root.width - width) / 2
        y: Math.round((root.height - height) / 2)
        transform: Translate { x: root.down ? 1 : 0; y: root.down ? 1 : 0 }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: root.iconSize
            opacity: root.enabled ? 1 : 0.45
        }
        Item { id: slot; width: childrenRect.width; height: childrenRect.height; anchors.verticalCenter: parent.verticalCenter }
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            kind: root.glyph || "close"
            etched: !root.enabled
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            bold: root.bold
            enabled: root.enabled
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width - root.padding * 2 - (root.icon ? root.iconSize + 6 : 0))
        }
    }

    FocusRect {
        anchors.fill: parent
        anchors.margins: 4
        visible: root.activeFocus && root.text !== ""
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
