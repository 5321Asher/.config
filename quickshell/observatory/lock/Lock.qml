import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

// 8 · Lock screen. A real Wayland session lock (WlSessionLock) with the LockFace on every monitor;
// plus a preview window (qs ipc call lock preview) showing the same face without locking anything.
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

    WlSessionLock {
        locked: LockState.locked

        WlSessionLockSurface {
            color: Theme.bgDark

            LockFace {
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
        exclusionMode: ExclusionMode.Ignore
        color: Theme.bgDark
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "observatory-lock-preview"
        WlrLayershell.keyboardFocus: LockState.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        LockFace {
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
