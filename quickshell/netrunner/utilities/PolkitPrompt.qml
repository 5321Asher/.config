import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "../theme"
import "../widgets"

// The polkit agent (admin passwords for pkexec, disk tools, installers…): ROOT ACCESS 管理者 as a red
// holocall (widgets/Holocall.qml) from the program that wants root, read from the request. It asks for
// the passphrase. A wrong one bursts red static, says ACCESS DENIED, and the line stays open; success
// hangs up; Esc or ABORT drops the call.
// Testing without polkit: qs ipc call polkit preview | close (the preview's passphrase is "netrunner").
Scope {
    id: root

    PolkitAgent { id: agent }
    readonly property var flow: preview.active ? preview : agent.flow
    readonly property bool open: preview.active || (agent.isActive && agent.flow !== null)

    function authorise() { if (flow?.isResponseRequired) flow.submit(field.text); }
    function cancel() { call.drop(); flow?.cancelAuthenticationRequest(); }

    // the program asking: the command in the message (pkexec's `/usr/bin/foo'), else the action
    function program(f) {
        const m = (f?.message ?? "").match(/[`'"‘“]([^`'"’”]+)[`'"’”]/);
        if (m) return m[1].trim().split(/\s+/)[0].split("/").pop();
        const skip = ["org", "freedesktop", "gnome", "kde", "policykit", "com", "net", "io", "github"];
        return (f?.actionId ?? "").split(".").filter(s => !skip.includes(s)).slice(-2).join(" ") || "system";
    }

    onOpenChanged: {
        if (open) { field.text = ""; field.focusField(); call.call(); }
        else call.hangUp();              // finished without a signal we heard: end it cleanly
    }
    Connections {
        target: agent.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) { field.text = ""; field.focusField(); } }
        function onAuthenticationFailed() { call.deny(); }
        function onAuthenticationSucceeded() { call.hangUp(); }
        function onAuthenticationRequestCancelled() { call.drop(); }
    }

    // a stand-in flow for testing the look without polkit
    QtObject {
        id: preview
        property bool active: false
        property string message: "Authentication is required to run `/usr/bin/true' as the super user"
        property string iconName: ""
        property string actionId: "org.freedesktop.policykit.exec"
        property string inputPrompt: "Password: "
        property bool responseVisible: false
        property bool isResponseRequired: true
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        function submit(text) { isResponseRequired = false; verify.text = text; verify.restart(); }
        function cancelAuthenticationRequest() { active = false; }
    }
    Timer {
        id: verify
        property string text
        interval: 450
        onTriggered: {
            if (text === "netrunner") { call.hangUp(); preview.active = false; return; }
            preview.supplementaryMessage = "Sorry, try again.";
            preview.supplementaryIsError = true;
            call.deny();
            preview.isResponseRequired = true;
            field.text = "";
            field.focusField();
        }
    }
    IpcHandler {
        target: "polkit"
        function preview(): void {
            preview.supplementaryMessage = "";
            preview.supplementaryIsError = false;
            preview.isResponseRequired = true;
            preview.active = true;
        }
        function close(): void { if (preview.active) root.cancel(); }
        function state(): string { return `open=${root.open} phase=${call.phase}`; }
    }

    PanelWindow {
        id: win
        Binding on screen {
            when: !win.visible
            value: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            restoreMode: Binding.RestoreNone
        }
        visible: root.open || call.busy
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "netrunner-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: root.open ? null : noInput
        Region { id: noInput }

        Rectangle { anchors.fill: parent; color: Theme.alpha(Theme.bgDark, 0.72 * call.presence) }
        MouseArea { anchors.fill: parent }

        Holocall {
            id: call
            width: Math.min(820, win.width - 64)
            height: implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(win.height * 0.24)
            caller: root.program(root.flow).toUpperCase()
            avatar: root.flow?.iconName || "dialog-password"
            line: root.flow?.message ?? ""
            tint: Theme.red
            tag: "ROOT ACCESS"
            jp: "管理者認証"
            hints: "ENTER AUTHORISE   //   ESC ABORT"
            status: root.flow?.isResponseRequired === false ? "VERIFYING" : "SECURE"

            Column {
                width: parent.width
                spacing: 10

                Label {
                    opacity: call.appear(0)
                    text: "OPERATOR  //  " + (Quickshell.env("USER") ?? "") + (root.flow?.isResponseRequired === false ? "  //  VERIFYING…" : "")
                }
                Field {
                    id: field
                    width: parent.width
                    height: 38
                    opacity: call.appear(1)
                    password: !(root.flow?.responseVisible ?? false)
                    enabled: root.flow?.isResponseRequired ?? false
                    placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "").toLowerCase() || "passphrase"
                    input.font.pixelSize: 16
                    onAccepted: root.authorise()
                    input.Keys.onEscapePressed: root.cancel()
                }
                Label {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: !(root.flow?.supplementaryMessage) ? "" : (root.flow.supplementaryIsError ? "ACCESS DENIED  //  " : "") + root.flow.supplementaryMessage
                    color: root.flow?.supplementaryIsError ? Theme.red : Theme.dim
                    strong: root.flow?.supplementaryIsError ?? false
                }
                Item {
                    width: parent.width
                    height: 30
                    opacity: call.appear(2)
                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        Btn { text: "abort"; onClicked: root.cancel() }
                        Btn { text: "authorise"; primary: true; enabled: root.flow?.isResponseRequired ?? false; onClicked: root.authorise() }
                    }
                }
            }
        }
    }
}
