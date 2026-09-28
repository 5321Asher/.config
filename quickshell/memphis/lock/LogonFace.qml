import QtQuick
import Quickshell
import "../theme"
import "../widgets"

// What the lock looks like on one screen: the desktop as it was breaks up into square blocks,
// revealing the plain desktop colour, and 98's logon box appears ("Welcome to Memphis": the keys,
// your user name, a password box, OK / Cancel). Unlocking runs it backwards. A wrong password
// brings up 98's message box and clears the box. Only the main screen gets the dialog.
Item {
    id: root

    property string screenName: ""
    property bool main: true
    property bool preview: false

    // 0 = the desktop as it was, 1 = the lock
    property real presence: LockState.revealed ? 1 : 0
    Behavior on presence { NumberAnimation { duration: LockState.revealed ? Theme.lockIntro : Theme.lockOutro; easing.type: Easing.Linear } }

    // ---------------------------------------------------------------- the dissolve
    Image {
        id: shot
        anchors.fill: parent
        cache: false
        source: root.screenName ? LockState.shotPath(root.screenName) : ""
    }
    Item {
        anchors.fill: parent
        Repeater {
            id: blocks
            readonly property int size: Theme.lockBlocks
            readonly property int cols: Math.ceil(root.width / size)
            model: cols * Math.ceil(root.height / size)
            Rectangle {
                required property int index
                readonly property real at: Math.random() * 0.94
                x: (index % blocks.cols) * blocks.size
                y: Math.floor(index / blocks.cols) * blocks.size
                width: blocks.size
                height: blocks.size
                visible: root.presence > at || shot.status !== Image.Ready
                color: Theme.desktop
            }
        }
    }

    // ---------------------------------------------------------------- the logon box
    Win {
        id: box
        visible: root.main && root.presence > 0.98 && !LockState.leaving
        anchors.centerIn: parent
        width: 470
        height: 230
        title: "Welcome to Memphis"
        helpButton: true
        closable: false

        Icon { x: 14; y: 14; name: "dialog-password"; fallback: "system-lock-screen"; size: 48 }
        Column {
            x: 80; y: 12
            width: parent.width - 96
            spacing: 10
            Txt {
                width: parent.width
                wrapMode: Text.Wrap
                text: LockState.status === "verifying" ? "Checking your password…" : "Type your password to unlock Memphis."
            }
            Row {
                spacing: 8
                Txt { width: 96; height: Theme.field; text: "User name:" }
                Field { width: 200; readOnly: true; text: LockState.user }
            }
            Row {
                spacing: 8
                Txt { width: 96; height: Theme.field; text: "Password:" }
                // what's typed lives in LockState (the keyboard goes to an invisible box); 98 showed asterisks
                Bevel {
                    width: 200
                    height: Theme.field
                    kind: "sunken"
                    fill: Theme.window
                    Txt {
                        x: 5
                        height: parent.height
                        color: Theme.windowText
                        text: "*".repeat(Math.min(24, LockState.buffer.length))
                    }
                    // the caret
                    Rectangle {
                        x: 5 + Math.min(24, LockState.buffer.length) * 8
                        y: 5
                        width: 1
                        height: parent.height - 10
                        color: Theme.windowText
                        SequentialAnimation on visible {
                            loops: Animation.Infinite
                            PropertyAction { value: true } PauseAnimation { duration: 530 }
                            PropertyAction { value: false } PauseAnimation { duration: 530 }
                        }
                    }
                }
            }
        }
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            Row {
                spacing: 8
                Btn { text: "OK"; isDefault: true; activeFocusOnTab: false; onClicked: LockState.submit() }
                Btn {
                    text: "Cancel"
                    activeFocusOnTab: false
                    onClicked: root.preview ? LockState.closePreview() : (LockState.buffer = "")
                }
            }
        }
    }

    // 98's message box for a wrong password (or a PAM error)
    Win {
        visible: root.main && (LockState.status === "denied" || LockState.status === "error") && !LockState.leaving
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 60
        anchors.horizontalCenterOffset: 40
        width: 400
        height: 160
        title: "Memphis"
        Icon { x: 14; y: 14; name: "dialog-error"; size: 40 }
        Txt {
            x: 70; y: 12
            width: parent.width - 86
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignTop
            text: LockState.status === "error" ? "Memphis couldn't check the password" + (LockState.detail ? ":\n" + LockState.detail : ".") + "\nTry again."
                : "The password is not correct. Type it again, making sure Caps Lock isn't on."
        }
        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: "OK"
            isDefault: true
            onClicked: LockState.status = "idle"
        }
    }

    // the time, down in the corner where the clock was
    Txt {
        visible: root.presence > 0.98 && !LockState.leaving
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        text: Qt.formatDateTime(clock.date, "dddd, MMMM d   h:mm AP")
        color: "#ffffff"
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
}
