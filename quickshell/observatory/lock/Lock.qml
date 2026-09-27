import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

// 8 · Lock screen. A real Wayland session lock (WlSessionLock) with the LockFace on every monitor;
// plus a preview window (qs ipc call lock preview) showing the same face without locking anything.
// Both start on a snapshot of the desktop (LockState.snap), which blurs away under the sky as the
// face arrives, and comes back into focus as it leaves.
Scope {
    id: root

    // Keys go to whichever surface has the keyboard; the text lives in LockState
    component Keyboard: TextInput {
        property bool preview: false
        opacity: 0
        width: 1
        height: 1
        focus: true
        echoMode: TextInput.Password
        text: LockState.buffer
        onTextEdited: {
            LockState.buffer = text;
            if (LockState.status === "denied" || LockState.status === "error") LockState.status = "idle";
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                LockState.submit();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (preview) LockState.closePreview();
                else LockState.buffer = "";
                event.accepted = true;
            }
        }
    }

    // The desktop as it was, blurring and dimming as the face arrives (presence 0 -> 1)
    component Backdrop: Item {
        id: bd
        property string screenName
        property real presence
        Image {
            id: shot
            anchors.fill: parent
            visible: false
            cache: false
            source: LockState.shotPath(bd.screenName)
        }
        MultiEffect {
            anchors.fill: parent
            source: shot
            visible: shot.status === Image.Ready
            blurEnabled: true
            blurMax: 64
            blur: Theme.lockBackdropBlur * bd.presence
            brightness: -0.25 * bd.presence
            saturation: -0.4 * bd.presence
        }
    }

    WlSessionLock {
        locked: LockState.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.bgDark

            Backdrop {
                anchors.fill: parent
                screenName: surface.screen?.name ?? ""
                presence: face.presence
            }
            LockFace {
                id: face
                anchors.fill: parent
            }
            Keyboard {
                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    PanelWindow {
        visible: LockState.previewing
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        id: previewWindow
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "observatory-lock-preview"
        WlrLayershell.keyboardFocus: LockState.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Backdrop {
            anchors.fill: parent
            screenName: previewWindow.screen?.name ?? ""
            presence: previewFace.presence
        }
        LockFace {
            id: previewFace
            anchors.fill: parent
            preview: true
        }
        Keyboard {
            id: previewKeys
            preview: true
        }
        onVisibleChanged: if (visible) previewKeys.forceActiveFocus()
    }
}
