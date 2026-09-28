import QtQuick
import "../theme"

// A check box (or, with radio: true, an option button): the sunken white box and its label.
// Clicking the label works too. `toggled()` fires on a click; bind `checked` to the real state.
Item {
    id: root

    property string text: ""
    property bool checked: false
    property bool radio: false
    signal toggled()

    implicitWidth: box.width + (text ? label.implicitWidth + 8 : 0)
    implicitHeight: Math.max(Theme.check, label.implicitHeight) + 4
    activeFocusOnTab: true
    Keys.onSpacePressed: root.toggled()

    // square box
    Bevel {
        id: box
        visible: !root.radio
        width: Theme.check
        height: Theme.check
        anchors.verticalCenter: parent.verticalCenter
        kind: "sunken"
        fill: mouse.pressed || !root.enabled ? Theme.face : Theme.window
        Glyph {
            anchors.centerIn: parent
            visible: root.checked
            kind: "check"
            color: root.enabled ? Theme.windowText : Theme.grayText
        }
    }
    // round box, drawn: 98's option buttons are a 12 px circle with the same two-tone edge
    Canvas {
        id: circle
        visible: root.radio
        width: Theme.check
        height: Theme.check
        anchors.verticalCenter: parent.verticalCenter
        readonly property color inner: mouse.pressed || !root.enabled ? Theme.face : Theme.window
        onInnerChanged: requestPaint()
        Connections { target: Theme; function onPaletteChanged() { circle.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const c = width / 2, r = width / 2;
            const arc = (rad, from, to, col) => {
                ctx.strokeStyle = col; ctx.lineWidth = 1;
                ctx.beginPath(); ctx.arc(c, c, rad, from, to); ctx.stroke();
            };
            ctx.fillStyle = inner;
            ctx.beginPath(); ctx.arc(c, c, r - 2, 0, 2 * Math.PI); ctx.fill();
            // top-left halves dark, bottom-right halves light
            arc(r - 0.5, Math.PI * 0.75, Math.PI * 1.75, Theme.shadow);
            arc(r - 0.5, Math.PI * 1.75, Math.PI * 2.75, Theme.hilight);
            arc(r - 1.5, Math.PI * 0.75, Math.PI * 1.75, Theme.dkShadow);
            arc(r - 1.5, Math.PI * 1.75, Math.PI * 2.75, Theme.light);
        }
        Glyph {
            anchors.centerIn: parent
            visible: root.checked
            kind: "dot"
            px: 1
            color: root.enabled ? Theme.windowText : Theme.grayText
        }
    }

    Txt {
        id: label
        x: Theme.check + 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        enabled: root.enabled
        FocusRect {
            anchors.fill: parent
            anchors.margins: -1
            visible: root.activeFocus
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        onClicked: { root.forceActiveFocus(); root.toggled(); }
    }
}
