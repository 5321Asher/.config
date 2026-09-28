import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"
import "../flyouts"

// Notifications as Windows 11's toasts: they slide in at the bottom right above the clock (the
// newest at the bottom), stay 6 seconds (longer while you point at one; urgent ones until closed),
// then slide back out. Click one to open its app (its default action); its buttons along the bottom.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Flyouts.focusedScreen()?.name) ?? Quickshell.screens[0]
    visible: Notifs.model.count > 0 && !(Flyouts.isOpen && Flyouts.kind === "notif")
    anchors { bottom: true; right: true }
    margins { bottom: 12; right: 12 }
    exclusionMode: ExclusionMode.Normal
    implicitWidth: Theme.toastWidth + 40
    implicitHeight: Math.max(1, stack.height + 30)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "disguise-toast"

    Column {
        id: stack
        x: 20; y: 10
        width: Theme.toastWidth
        spacing: 12
        move: Transition { NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }
        Repeater {
            // newest at the bottom
            model: Notifs.model
            delegate: Toast {}
        }
        // Notifs.model is newest first: flip it
        rotation: 180
    }

    component Toast: Item {
        id: toast
        required property int nid
        readonly property var n: Notifs.notification(nid)
        readonly property bool critical: n?.urgency === NotificationUrgency.Critical
        width: Theme.toastWidth
        height: body.implicitHeight + 24
        rotation: 180          // (the stack is flipped)
        property bool leaving: false
        x: 0
        opacity: 1
        Component.onCompleted: { enter.start(); if (!critical) life.start(); }
        NumberAnimation { id: enter; target: toast; property: "x"; from: -(Theme.toastWidth + 40); to: 0; duration: Theme.slow; easing.type: Easing.OutCubic }
        function leave() {
            if (leaving) return;
            leaving = true;
            out.start();
        }
        SequentialAnimation {
            id: out
            NumberAnimation { target: toast; property: "x"; to: -(Theme.toastWidth + 40); duration: Theme.normal; easing.type: Easing.InCubic }
            ScriptAction { script: Notifs.drop(toast.nid) }
        }
        Timer { id: life; interval: Theme.toastTimeout; onTriggered: if (!hover.containsMouse) toast.leave(); else restart() }
        Connections {
            target: toast.n
            function onClosed() { toast.leave(); }
        }

        Acrylic { anchors.fill: parent; tintAlpha: Theme.dark ? 0.94 : 0.92 }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                const def = (toast.n?.actions ?? []).find(a => a.identifier === "default");
                if (def) def.invoke();
                toast.leave();
            }
        }
        Column {
            id: body
            x: 16; y: 12
            width: parent.width - 32
            spacing: 8
            Item {
                width: parent.width; height: 20
                AppIcon { size: 16; anchors.verticalCenter: parent.verticalCenter; name: toast.n?.appIcon || (toast.n?.appName ?? "").toLowerCase() || "dialog-information" }
                Txt { x: 24; width: parent.width - 60; height: parent.height; text: toast.n?.appName || "Notification"; size: Theme.caption }
                Btn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "subtle"; glyph: ""; glyphSize: 10; width: 26; height: 26
                    visible: hover.containsMouse || hovered || toast.critical
                    onClicked: { toast.n?.dismiss(); toast.leave(); }
                }
            }
            Row {
                width: parent.width
                spacing: 12
                ClippingRectangle {
                    visible: (toast.n?.image ?? "") !== ""
                    width: 48; height: 48; radius: Theme.radius
                    color: "transparent"
                    Image { anchors.fill: parent; source: toast.n?.image ?? ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 96; asynchronous: true }
                }
                Column {
                    width: parent.width - ((toast.n?.image ?? "") !== "" ? 60 : 0)
                    spacing: 2
                    Txt { width: parent.width; text: toast.n?.summary ?? ""; strong: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
                    Txt { width: parent.width; text: toast.n?.body ?? ""; level: 2; wrapMode: Text.Wrap; maximumLineCount: 4; textFormat: Text.StyledText; visible: text !== "" }
                }
            }
            Row {
                readonly property var acts: (toast.n?.actions ?? []).filter(a => a.identifier !== "default")
                visible: acts.length > 0
                width: parent.width
                spacing: 8
                Repeater {
                    model: parent.acts
                    Btn {
                        required property var modelData
                        width: (body.width - 8 * (parent.acts.length - 1)) / parent.acts.length
                        text: modelData.text
                        onClicked: { modelData.invoke(); toast.leave(); }
                    }
                }
            }
        }
    }
}
