import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Focus Timer Properties: a pomodoro (focus, short break, long break every few rounds) or a plain
// countdown. The time shows on a black LCD; while it runs an hourglass sits in the notification
// area. services/FocusTimer.qml keeps time and sends the notifications.
Props {
    id: root

    title: "Focus Timer Properties"
    icon: "appointment-soon"
    tabs: ["Timer", "Settings"]

    // ---------------------------------------------------------------- Timer
    Column {
        spacing: 12
        Row {
            spacing: 18
            Check { radio: true; text: "Pomodoro"; checked: FocusTimer.mode === "pomodoro"; onToggled: FocusTimer.setMode("pomodoro") }
            Check { radio: true; text: "Countdown"; checked: FocusTimer.mode === "timer"; onToggled: FocusTimer.setMode("timer") }
        }
        // the LCD
        Bevel {
            width: parent.width
            height: 132
            kind: "sunken"
            fill: Theme.lcd
            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: FocusTimer.remainingText
                    color: Theme.lcdText
                    font.family: Theme.fontMono
                    font.pixelSize: 64
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: FocusTimer.phaseLabel.toUpperCase() + (FocusTimer.mode === "pomodoro" ? "   ROUND " + Math.min(FocusTimer.rounds, FocusTimer.completed + 1) + " OF " + FocusTimer.rounds : "")
                        + (FocusTimer.running ? "" : FocusTimer.active ? "   PAUSED" : "")
                    color: Qt.darker(Theme.lcdText, 1.4)
                    font.family: Theme.fontMono
                    font.pixelSize: 16
                }
            }
        }
        Progress { width: parent.width; height: 24; value: 1 - FocusTimer.progress }
        Row {
            spacing: 6
            Btn { text: FocusTimer.running ? "Pause" : FocusTimer.active ? "Resume" : "Start"; isDefault: true; onClicked: FocusTimer.toggle() }
            Btn { text: "Reset"; enabled: FocusTimer.active; onClicked: FocusTimer.reset() }
            Btn { text: FocusTimer.mode === "pomodoro" ? "Skip" : "Restart"; onClicked: FocusTimer.skip() }
        }
    }

    // ---------------------------------------------------------------- Settings
    Column {
        spacing: 10
        Group {
            title: "Pomodoro"
            width: parent.width
            Row { spacing: 10; Txt { width: 170; height: Theme.field; text: "Focus:" } Spin { from: 1; to: 180; suffix: " min"; value: FocusTimer.focusMins; onChanged: v => FocusTimer.setPhaseMins("focus", v) } }
            Row { spacing: 10; Txt { width: 170; height: Theme.field; text: "Short break:" } Spin { from: 1; to: 180; suffix: " min"; value: FocusTimer.shortMins; onChanged: v => FocusTimer.setPhaseMins("short", v) } }
            Row { spacing: 10; Txt { width: 170; height: Theme.field; text: "Long break:" } Spin { from: 1; to: 180; suffix: " min"; value: FocusTimer.longMins; onChanged: v => FocusTimer.setPhaseMins("long", v) } }
            Row { spacing: 10; Txt { width: 170; height: Theme.field; text: "Rounds before a long break:" } Spin { from: 1; to: 12; value: FocusTimer.rounds; onChanged: v => FocusTimer.rounds = v } }
            Check { text: "Start the next phase by itself"; checked: FocusTimer.autoStart; onToggled: FocusTimer.autoStart = !FocusTimer.autoStart }
        }
        Group {
            title: "Countdown"
            width: parent.width
            Row { spacing: 10; Txt { width: 170; height: Theme.field; text: "Length:" } Spin { from: 1; to: 600; suffix: " min"; value: FocusTimer.timerMins; onChanged: v => FocusTimer.setTimerMins(v) } }
            Row {
                spacing: 6
                Repeater {
                    model: [5, 10, 15, 30, 60]
                    Btn { required property int modelData; text: modelData + " min"; implicitWidth: 76; onClicked: { FocusTimer.setMode("timer"); FocusTimer.setTimerMins(modelData); } }
                }
            }
        }
    }
}
