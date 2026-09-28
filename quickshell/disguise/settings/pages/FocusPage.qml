import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Focus: a big ring with the time left, start / pause / reset / skip, and the session settings
// (a plain countdown, or pomodoro: focus, short and long breaks, rounds).
Column {
    id: root
    spacing: 4

    Card {
        width: parent.width
        height: 300
        Item {
            id: dial
            width: 200; height: 200
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
            Ring { anchors.fill: parent; thickness: 8; value: FocusTimer.active ? 1 - FocusTimer.progress : 0; track: Theme.subtle }
            Column {
                anchors.centerIn: parent
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: FocusTimer.remainingText; size: Theme.titleLarge; strong: true }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    level: 2
                    text: FocusTimer.phaseLabel + (FocusTimer.mode === "pomodoro" ? " · " + Math.min(FocusTimer.rounds, FocusTimer.completed + 1) + " of " + FocusTimer.rounds : "")
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.y + dial.height + 20
            spacing: 8
            Btn { kind: "accent"; glyph: FocusTimer.running ? "" : ""; text: FocusTimer.running ? "Pause" : FocusTimer.active ? "Resume" : "Start focus session"; onClicked: FocusTimer.toggle() }
            Btn { glyph: ""; text: "Reset"; enabled: FocusTimer.active; onClicked: FocusTimer.reset() }
            Btn { glyph: ""; text: FocusTimer.mode === "pomodoro" ? "Skip" : "Restart"; onClicked: FocusTimer.skip() }
        }
    }
    Header { text: "Session" }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Kind of session"; subtitle: "A single countdown, or pomodoro rounds with breaks"
        Combo { width: 180; model: ["Countdown", "Pomodoro"]; currentIndex: FocusTimer.mode === "timer" ? 0 : 1; onChosen: i => FocusTimer.setMode(i === 0 ? "timer" : "pomodoro") }
    }
    SettingRow {
        visible: FocusTimer.mode === "timer"
        width: parent.width
        glyph: ""; title: "Length"
        Stepper { value: FocusTimer.timerMins; step: 5; suffix: " mins"; onChanged: v => FocusTimer.setTimerMins(v) }
    }
    SettingRow {
        visible: FocusTimer.mode === "pomodoro"
        width: parent.width
        glyph: ""; title: "Focus"
        Stepper { value: FocusTimer.focusMins; step: 5; suffix: " mins"; onChanged: v => FocusTimer.setPhaseMins("focus", v) }
    }
    SettingRow {
        visible: FocusTimer.mode === "pomodoro"
        width: parent.width
        glyph: ""; title: "Short break"
        Stepper { value: FocusTimer.shortMins; step: 1; suffix: " mins"; onChanged: v => FocusTimer.setPhaseMins("short", v) }
    }
    SettingRow {
        visible: FocusTimer.mode === "pomodoro"
        width: parent.width
        glyph: ""; title: "Long break"
        Stepper { value: FocusTimer.longMins; step: 5; suffix: " mins"; onChanged: v => FocusTimer.setPhaseMins("long", v) }
    }
    SettingRow {
        visible: FocusTimer.mode === "pomodoro"
        width: parent.width
        glyph: ""; title: "Rounds before a long break"
        Stepper { value: FocusTimer.rounds; step: 1; min: 1; max: 12; onChanged: v => FocusTimer.rounds = v }
    }
    SettingRow {
        visible: FocusTimer.mode === "pomodoro"
        width: parent.width
        glyph: ""; title: "Start the next part by itself"
        Toggle { checked: FocusTimer.autoStart; onToggled: FocusTimer.autoStart = !FocusTimer.autoStart }
    }

    // − value +
    component Stepper: Row {
        id: st
        property int value
        property int step: 1
        property int min: 1
        property int max: 600
        property string suffix: ""
        signal changed(int v)
        spacing: 4
        Btn { kind: "subtle"; glyph: ""; width: 32; onClicked: st.changed(Math.max(st.min, st.value - st.step)) }
        Txt { width: 80; height: 32; horizontalAlignment: Text.AlignHCenter; text: st.value + st.suffix }
        Btn { kind: "subtle"; glyph: ""; width: 32; onClicked: st.changed(Math.min(st.max, st.value + st.step)) }
    }
}
