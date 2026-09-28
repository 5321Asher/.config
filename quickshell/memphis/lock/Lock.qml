import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

// The lock screen. A real Wayland session lock (WlSessionLock) with the LogonFace on every monitor
// (the dialog on the one that had focus); plus a preview window (qs ipc call lock preview) showing
// the same face without locking anything. Esc clears the password (and closes the preview).
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
                if (LockState.status === "denied" || LockState.status === "error") LockState.status = "idle";
                else LockState.submit();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (preview) LockState.closePreview();
                else { LockState.buffer = ""; LockState.status = "idle"; }
                event.accepted = true;
            }
        }
    }

    WlSessionLock {
        locked: LockState.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.desktop
            LogonFace {
                anchors.fill: parent
                screenName: surface.screen?.name ?? ""
                main: (surface.screen?.name ?? "") === LockState.mainScreen || Quickshell.screens.length === 1
            }
            Keyboard { Component.onCompleted: forceActiveFocus() }
        }
    }

    PanelWindow {
        id: previewWindow
        visible: LockState.previewing
        screen: Quickshell.screens.find(s => s.name === LockState.mainScreen) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "memphis-lock-preview"
        WlrLayershell.keyboardFocus: LockState.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        LogonFace {
            anchors.fill: parent
            screenName: previewWindow.screen?.name ?? ""
            preview: true
        }
        Keyboard { id: previewKeys; preview: true }
        onVisibleChanged: if (visible) previewKeys.forceActiveFocus()
    }
}
