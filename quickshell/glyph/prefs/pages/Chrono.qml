import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"

// FOCUS: the focus timer, pomodoro (focus, short break, long break every few rounds) or a plain
// countdown: the time in Doto inside a ring of 60 dots that empties as it runs (the rail and the
// bottom edge show it too).
Column {
    id: root

    spacing: 34

    Row {
        spacing: 8
        Btn { text: "pomodoro"; on: FocusTimer.mode === "pomodoro"; onClicked: FocusTimer.setMode("pomodoro") }
        Btn { text: "countdown"; on: FocusTimer.mode === "timer"; onClicked: FocusTimer.setMode("timer") }
    }

    Row {
        spacing: 50
        Item {
            width: 380
            height: 380
            Ring { anchors.fill: parent; n: 60; dot: 9; f: FocusTimer.active ? 1 - FocusTimer.progress : 1; on: FocusTimer.running ? Theme.fg : Theme.grey }
            Column {
                anchors.centerIn: parent
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: FocusTimer.phaseLabel }
                Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 10; bottomPadding: lead + 10; text: FocusTimer.remainingText; font.pixelSize: 96 }
                Lb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: FocusTimer.mode === "pomodoro" ? "round " + Math.min(FocusTimer.rounds, FocusTimer.completed + 1) + " of " + FocusTimer.rounds
                                                        : FocusTimer.running ? "running" : FocusTimer.active ? "paused" : "ready"
                }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            // start: the red disc (the live thing), as the player's play button
            Rectangle {
                width: 96
                height: 96
                radius: 48
                color: Theme.red
                Icon { anchors.centerIn: parent; text: FocusTimer.running ? "\u{F03E4}" : "\u{F040A}"; color: "#FFFFFF"; font.pixelSize: 40 }
                TapHandler { onTapped: FocusTimer.toggle() }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
            Btn { text: "reset"; enabled: FocusTimer.active; onClicked: FocusTimer.reset() }
            Btn { text: FocusTimer.mode === "pomodoro" ? "skip" : "restart"; onClicked: FocusTimer.skip() }
        }
    }

    Section {
        visible: FocusTimer.mode === "pomodoro"
        title: "pomodoro"
        Stepper { label: "focus"; value: FocusTimer.focusMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("focus", v) }
        Stepper { label: "short break"; value: FocusTimer.shortMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("short", v) }
        Stepper { label: "long break"; value: FocusTimer.longMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("long", v) }
        Stepper { label: "rounds"; value: FocusTimer.rounds; unit: ""; onChangedTo: v => FocusTimer.rounds = Math.max(1, Math.min(12, v)) }
        Row {
            spacing: 14
            Switch { checked: FocusTimer.autoStart; onToggled: FocusTimer.autoStart = !FocusTimer.autoStart }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: "start the next phase by itself" }
        }
    }
    Section {
        visible: FocusTimer.mode === "timer"
        title: "countdown"
        Stepper { label: "length"; value: FocusTimer.timerMins; unit: "min"; onChangedTo: v => FocusTimer.setTimerMins(v) }
        Flow {
            width: parent.width
            spacing: 8
            Repeater { model: [5, 10, 15, 25, 45, 60]; Btn { required property int modelData; text: modelData + " min"; on: FocusTimer.timerMins === modelData; onClicked: FocusTimer.setTimerMins(modelData) } }
        }
    }

    component Stepper: Item {
        id: st
        property string label
        property int value
        property string unit
        signal changedTo(int v)
        width: parent.width
        height: 48
        Lb { anchors.verticalCenter: parent.verticalCenter; text: st.label }
        Row {
            anchors.right: parent.right
            spacing: 14
            Btn { glyph: "\u{F0374}"; width: 48; onClicked: st.changedTo(st.value - 1) }
            Num { anchors.verticalCenter: parent.verticalCenter; width: 70; horizontalAlignment: Text.AlignHCenter; text: st.value; font.pixelSize: 34 }
            Btn { glyph: "\u{F0415}"; width: 48; onClicked: st.changedTo(st.value + 1) }
        }
    }
}
