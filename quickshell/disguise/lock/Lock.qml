import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

// The lock screen. A real Wayland session lock (WlSessionLock) with the LockFace on every monitor
// (the sign-in on the one that had focus); plus a preview window (qs ipc call lock preview) showing
// the same face without locking anything.
Scope {
    id: root

    // Keys go to whichever surface has the keyboard; the text lives in LockState. On the curtain a
    // key lifts it (and a printable key starts the password, as on Windows).
    component Keyboard: TextInput {
        property bool preview: false
        opacity: 0
        width: 1
        height: 1
        focus: true
        echoMode: TextInput.Password
        text: LockState.buffer
        onTextEdited: {
            if (LockState.curtain) LockState.lift();
            LockState.buffer = text;
            if (LockState.status === "denied" || LockState.status === "error") LockState.status = "idle";
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (LockState.curtain) LockState.lift();
                else if (LockState.status === "denied" || LockState.status === "error") LockState.status = "idle";
                else LockState.submit();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (preview && (LockState.curtain || LockState.buffer === "")) LockState.closePreview();
                else if (LockState.buffer === "" && !LockState.curtain) LockState.drop();
                else { LockState.buffer = ""; LockState.status = "idle"; }
                event.accepted = true;
            } else if (LockState.curtain && (event.key === Qt.Key_Space || event.key === Qt.Key_Up)) {
                LockState.lift();
                event.accepted = true;
            }
        }
    }

    WlSessionLock {
        locked: LockState.locked

        WlSessionLockSurface {
            id: surface
            color: "#000000"
            LockFace {
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
        WlrLayershell.namespace: "disguise-lock-preview"
        WlrLayershell.keyboardFocus: LockState.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        LockFace {
            anchors.fill: parent
            screenName: previewWindow.screen?.name ?? ""
            preview: true
        }
        Keyboard { id: previewKeys; preview: true }
        onVisibleChanged: if (visible) previewKeys.forceActiveFocus()
    }
}
