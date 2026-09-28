import QtQuick
import QtQuick.Effects
import Quickshell
import "../theme"
import "../widgets"
import "../services"

// What the lock looks like (after the fourth reference): the desktop as it was, blurred and
// darkened; SESSION SUSPENDED // ICE ACTIVE top left with its hazard stripes; host, uplink and
// profile top right; the time huge in the middle with its seconds in red; OPERATOR // you and the
// date; the AUTH // PASSPHRASE box with a cell per character and the failed count; the queue,
// vulns and ICE along the bottom. Only the main screen gets the passphrase box.
Item {
    id: root

    property string screenName: ""
    property bool main: true
    property bool preview: false

    property real presence: LockState.revealed ? 1 : 0
    Behavior on presence { NumberAnimation { duration: LockState.revealed ? Theme.lockIntro : Theme.lockOutro; easing.type: Theme.easing } }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ---------------------------------------------------------------- the desktop, going under
    Rectangle { anchors.fill: parent; color: Theme.bgDark }
    Image {
        id: shot
        anchors.fill: parent
        visible: false
        cache: false
        source: root.screenName ? LockState.shotPath(root.screenName) : ""
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blurMax: 96
        blur: 1.0 * root.presence
        brightness: -0.5 * root.presence
        saturation: -0.2 * root.presence
    }
    // scanlines
    Canvas {
        anchors.fill: parent
        opacity: 0.25 * root.presence
        onPaint: {
            const ctx = getContext("2d");
            ctx.fillStyle = "#000000";
            for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
        }
    }
    // the red sweep line as it locks / unlocks
    Rectangle {
        visible: root.presence > 0.02 && root.presence < 0.98
        y: root.height * root.presence
        width: root.width
        height: 2
        color: Theme.red
        opacity: 0.8
    }

    Item {
        anchors.fill: parent
        opacity: Math.max(0, root.presence * 1.4 - 0.4)

        // ---------------------------------------------------------------- top left
        Column {
            x: 36; y: 36
            spacing: 8
            Hazard { width: 96; height: 10 }
            Row {
                spacing: 14
                Label { text: "SESSION SUSPENDED"; strong: true; color: Theme.bright }
                Label { text: "//  ICE ACTIVE"; strong: true; color: Theme.red }
            }
            Jp { text: "セッション停止 // 防壁稼働中" }
        }
        // ---------------------------------------------------------------- top right
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 36
            y: 40
            spacing: 8
            Label { anchors.right: parent.right; text: "HOST " + Status.host + "  //  UPLINK " + (Net.ssid || "WIRED") }
            Label { anchors.right: parent.right; text: "PROFILE  //  " + (Status.profile || "—") }
        }

        // ---------------------------------------------------------------- the time
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -110
            spacing: 6
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: 170
                    font.weight: Font.Bold
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 34
                    text: Qt.formatTime(clock.date, "ss")
                    color: Theme.red
                    font.family: Theme.display
                    font.pixelSize: 40
                    font.weight: Font.Bold
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Label { text: "OPERATOR" }
                Label { text: "//"; color: Theme.alpha(Theme.dim, 0.6) }
                Label { text: LockState.user; strong: true; color: Theme.bright }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Label { text: Qt.formatDate(clock.date, "MM.dd.yy"); strong: true; color: Theme.fg; font.pixelSize: Theme.data }
                Label { text: Qt.formatDate(clock.date, "ddd"); font.pixelSize: Theme.data }
            }
        }

        // ---------------------------------------------------------------- the passphrase
        Item {
            id: auth
            visible: root.main
            width: 560
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 40

            readonly property bool bad: LockState.status === "denied" || LockState.status === "error"

            Chamfer { anchors.fill: parent; cut: 16; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.72); stroke: auth.bad ? Theme.red : Theme.alpha(Theme.line, 1) }
            Row {
                x: 20; y: 18
                spacing: 10
                Label { text: "AUTH  //  PASSPHRASE"; strong: true; color: Theme.bright }
                Jp { text: "認証" }
            }
            Label { anchors.right: parent.right; anchors.rightMargin: 20; y: 20; text: "FAILED " + LockState.attempts; color: LockState.attempts > 0 ? Theme.red : Theme.dim }

            // a cell per character (16 shown; more just keep the last one lit)
            Row {
                id: cells
                anchors.horizontalCenter: parent.horizontalCenter
                y: 68
                spacing: 5
                Repeater {
                    model: 16
                    Rectangle {
                        required property int index
                        readonly property bool on: index < LockState.buffer.length
                        width: 26; height: 34
                        color: on ? Theme.alpha(auth.bad ? Theme.red : Theme.cyan, 0.2) : "transparent"
                        border.width: 1
                        border.color: auth.bad ? Theme.red : on ? Theme.cyan : Theme.alpha(Theme.dim, 0.5)
                        Rectangle { anchors.centerIn: parent; visible: parent.on; width: 8; height: 8; color: auth.bad ? Theme.red : Theme.cyan }
                        // the caret
                        Rectangle {
                            visible: index === Math.min(15, LockState.buffer.length) && LockState.status !== "verifying"
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter
                            width: 14; height: 2; color: Theme.red
                            SequentialAnimation on opacity { loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 1 } PauseAnimation { duration: 450 } NumberAnimation { to: 1; duration: 1 } PauseAnimation { duration: 450 } }
                        }
                    }
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: cells.y + cells.height + 26
                text: LockState.status === "verifying" ? "VERIFYING…"
                    : LockState.status === "denied" ? "ACCESS DENIED  //  TRY AGAIN"
                    : LockState.status === "error" ? "AUTH ERROR  //  " + (LockState.detail || "TRY AGAIN")
                    : root.preview ? "PREVIEW  //  ESC CLOSES" : "ENTER PASSPHRASE TO RESUME SESSION"
                color: auth.bad ? Theme.red : LockState.status === "verifying" ? Theme.cyan : Theme.dim
            }
        }

        // ---------------------------------------------------------------- the bottom line
        Row {
            x: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            spacing: 24
            Label { text: "QUEUE " + Queue.cleared + "/" + Queue.total + " CLEARED" }
            Label { text: Status.auditAvailable ? "VULN " + Status.vulnCount + " AFFECTED" : "VULN SCAN OFFLINE"; strong: true; color: Theme.fg }
            Label { text: "ICE " + Status.ice }
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            text: "SESSION " + Status.session + "   PWR AC"
        }
    }
}
