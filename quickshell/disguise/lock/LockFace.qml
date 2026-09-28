import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../theme"
import "../widgets"
import "../services"

// What the lock shows on one screen. Windows 11's lock screen: the wallpaper with the time large
// and the date under it (the curtain); a key or a click lifts it to the sign-in: the picture
// frosted, your account picture, your name, and the password box with its → button. Wrong: "The
// password is incorrect. Try again." with OK. It fades in over a snapshot of the desktop and fades
// back out to it when you sign in.
Item {
    id: root

    property string screenName: ""
    property bool main: true
    property bool preview: false

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // the wallpaper (skwd-wall's), else the desktop colour
    property string wall: ""
    FileView {
        path: Quickshell.env("HOME") + "/.cache/skwd-wall-v2/last-wallpaper.json"
        printErrors: false
        onLoaded: { try { const p = JSON.parse(text()).path ?? ""; root.wall = /\.(mp4|webm|mkv|gif)$/i.test(p) ? "" : p; } catch (e) {} }
    }
    property string fullName: ""
    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1']
        stdout: StdioCollector { onStreamFinished: root.fullName = text.trim() }
    }

    // the desktop as it was, under everything (the fade starts and ends on it)
    Image {
        anchors.fill: parent
        source: LockState.shotPath(root.screenName)
        fillMode: Image.PreserveAspectCrop
        cache: false
    }

    Item {
        id: face
        anchors.fill: parent
        opacity: LockState.revealed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: LockState.leaving ? Theme.lockOutro : Theme.lockIntro; easing.type: Easing.OutCubic } }

        Rectangle { anchors.fill: parent; color: Theme.desktop }
        Image {
            id: picture
            anchors.fill: parent
            source: root.wall ? "file://" + root.wall : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            asynchronous: true
            visible: false
        }
        // the frosted copy for the sign-in
        MultiEffect {
            anchors.fill: parent
            source: picture
            blurEnabled: true
            blur: LockState.curtain ? 0 : 1
            blurMax: 64
            brightness: LockState.curtain ? 0 : -0.12
            Behavior on blur { NumberAnimation { duration: Theme.slow } }
            Behavior on brightness { NumberAnimation { duration: Theme.slow } }
        }

        // ------------------------------------------------------------ the curtain: time and date
        Item {
            id: curtain
            width: parent.width
            height: parent.height
            y: LockState.curtain ? 0 : -parent.height * 0.12
            opacity: LockState.curtain ? 1 : 0
            visible: opacity > 0
            Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            Text {
                id: time
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.12
                text: Qt.formatTime(clock.date, "h:mm AP").replace(/\s*[AP]M$/i, "")
                color: "#ffffff"
                font.family: Theme.fontDisplay
                font.pixelSize: Math.min(134, parent.height * 0.17)
                font.weight: Font.DemiBold
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#60000000"; shadowBlur: 0.6 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: time.bottom
                text: Qt.formatDate(clock.date, "dddd, MMMM d")
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: 24
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#60000000"; shadowBlur: 0.5 }
            }
            MouseArea { anchors.fill: parent; onClicked: LockState.lift() }
        }

        // ------------------------------------------------------------ the sign-in
        Column {
            id: signin
            visible: root.main && opacity > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5 - 170 + (LockState.curtain ? 30 : 0)
            opacity: LockState.curtain ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
            spacing: 18

            Avatar { anchors.horizontalCenter: parent.horizontalCenter; size: 192 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.fullName || LockState.user
                color: "#ffffff"
                font.family: Theme.fontDisplay
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }
            // the password box (the keys go to LockState; this only draws it)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 296; height: 36
                visible: LockState.status !== "denied" && LockState.status !== "error"
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: Qt.alpha("#ffffff", 0.9)
                    border.width: 1
                    border.color: Qt.alpha("#ffffff", 0.3)
                    Rectangle { anchors.bottom: parent.bottom; x: 1; width: parent.width - 2; height: 2; color: Theme.logoBottom }
                }
                Text {
                    x: 12; width: parent.width - 60; height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: LockState.buffer === "" ? "Password" : "●".repeat(Math.min(LockState.buffer.length, 24))
                    color: LockState.buffer === "" ? "#5d5d5d" : "#1b1b1b"
                    font.family: Theme.font
                    font.pixelSize: LockState.buffer === "" ? 14 : 10
                    font.letterSpacing: LockState.buffer === "" ? 0 : 3
                }
                // the → button (a spinner while it checks)
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: Theme.radius
                    color: go.containsMouse ? Qt.alpha("#000000", 0.06) : "transparent"
                    Glyph { anchors.centerIn: parent; visible: LockState.status !== "verifying"; g: ""; size: 14; color: "#1b1b1b" }
                    Ring { anchors.centerIn: parent; visible: LockState.status === "verifying"; width: 18; height: 18; indeterminate: true; color: Theme.logoBottom }
                    MouseArea { id: go; anchors.fill: parent; hoverEnabled: true; onClicked: LockState.submit() }
                }
            }
            // wrong password
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: LockState.status === "denied" || LockState.status === "error"
                spacing: 18
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: LockState.status === "error" ? "Something went wrong. " + (LockState.detail || "Try again.") : "The password is incorrect. Try again."
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: 15
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 120; height: 32; radius: Theme.radius
                    color: okm.containsMouse ? Qt.alpha("#ffffff", 0.3) : Qt.alpha("#ffffff", 0.2)
                    border.width: 1; border.color: Qt.alpha("#ffffff", 0.35)
                    Text { anchors.centerIn: parent; text: "OK"; color: "#ffffff"; font.family: Theme.font; font.pixelSize: 14 }
                    MouseArea { id: okm; anchors.fill: parent; hoverEnabled: true; onClicked: LockState.status = "idle" }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: LockState.status !== "denied" && LockState.status !== "error"
                text: root.preview ? "Preview: Esc closes it" : "Sign-in options"
                color: Qt.alpha("#ffffff", 0.85)
                font.family: Theme.font
                font.pixelSize: 13
            }
        }

        // ------------------------------------------------------------ the corner: network, battery
        Row {
            anchors.right: parent.right; anchors.rightMargin: 28
            anchors.bottom: parent.bottom; anchors.bottomMargin: 24
            spacing: 22
            readonly property var bat: UPower.displayDevice
            Glyph { g: Net.ssid ? "" : ""; size: 18; color: "#ffffff" }
            Glyph {
                visible: parent.bat?.isLaptopBattery ?? false
                readonly property real pct: !parent.bat ? 0 : parent.bat.percentage > 1 ? parent.bat.percentage : parent.bat.percentage * 100
                g: String.fromCharCode((parent.bat?.state === UPowerDeviceState.Charging ? 0xebab : 0xeba0) + Math.round(pct / 10))
                size: 18; color: "#ffffff"
            }
            Glyph { visible: !LockState.curtain; g: ""; size: 18; color: "#ffffff" }
            Glyph { visible: !LockState.curtain; g: ""; size: 18; color: "#ffffff" }
        }
    }
}
