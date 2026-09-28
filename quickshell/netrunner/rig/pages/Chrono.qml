import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"

// 10 CHRONO 時計: the focus timer: pomodoro (focus, short break, long break every few rounds) or a
// plain countdown. The time in big display type; the bar shows it while it runs.
Column {
    id: root

    spacing: 22

    Row {
        spacing: 8
        Btn { text: "pomodoro"; on: FocusTimer.mode === "pomodoro"; onClicked: FocusTimer.setMode("pomodoro") }
        Btn { text: "countdown"; on: FocusTimer.mode === "timer"; onClicked: FocusTimer.setMode("timer") }
    }

    Item {
        width: parent.width
        height: 150
        Chamfer { anchors.fill: parent; cut: 14; corners: "tr bl"; fill: Theme.alpha(Theme.bgDark, 0.7); stroke: FocusTimer.running ? Theme.red : Theme.line }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: FocusTimer.remainingText
                color: FocusTimer.running ? Theme.bright : Theme.fg
                font.family: Theme.display
                font.pixelSize: 72
                font.weight: Font.Bold
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: FocusTimer.phaseLabel + (FocusTimer.mode === "pomodoro" ? "  //  round " + Math.min(FocusTimer.rounds, FocusTimer.completed + 1) + " of " + FocusTimer.rounds : "")
                      + (FocusTimer.running ? "" : FocusTimer.active ? "  //  paused" : "")
                color: FocusTimer.running ? Theme.red : Theme.dim
            }
        }
    }
    Blocks { count: 40; blockWidth: (root.width - 39 * 2) / 40; blockHeight: 6; value: 1 - FocusTimer.progress; color: Theme.red }
    Row {
        spacing: 8
        Btn { text: FocusTimer.running ? "pause" : FocusTimer.active ? "resume" : "start"; primary: true; onClicked: FocusTimer.toggle() }
        Btn { text: "reset"; enabled: FocusTimer.active; onClicked: FocusTimer.reset() }
        Btn { text: FocusTimer.mode === "pomodoro" ? "skip" : "restart"; onClicked: FocusTimer.skip() }
    }

    Section {
        visible: FocusTimer.mode === "pomodoro"
        title: "pomodoro"
        jp: "設定"
        Stepper { label: "focus"; value: FocusTimer.focusMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("focus", v) }
        Stepper { label: "short break"; value: FocusTimer.shortMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("short", v) }
        Stepper { label: "long break"; value: FocusTimer.longMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("long", v) }
        Stepper { label: "rounds"; value: FocusTimer.rounds; unit: ""; onChangedTo: v => FocusTimer.rounds = Math.max(1, Math.min(12, v)) }
        Row { spacing: 10; Switch { checked: FocusTimer.autoStart; onToggled: FocusTimer.autoStart = !FocusTimer.autoStart }
              Label { anchors.verticalCenter: parent.verticalCenter; text: "start the next phase by itself" } }
    }
    Section {
        visible: FocusTimer.mode === "timer"
        title: "countdown"
        jp: "設定"
        Stepper { label: "length"; value: FocusTimer.timerMins; unit: "min"; onChangedTo: v => FocusTimer.setTimerMins(v) }
        Flow {
            width: parent.width
            spacing: 6
            Repeater { model: [5, 10, 15, 25, 45, 60]; Btn { required property int modelData; text: modelData + "m"; on: FocusTimer.timerMins === modelData; onClicked: FocusTimer.setTimerMins(modelData) } }
        }
    }

    component Stepper: Item {
        id: st
        property string label
        property int value
        property string unit
        signal changedTo(int v)
        width: parent.width
        height: 28
        Label { anchors.verticalCenter: parent.verticalCenter; text: st.label }
        Row {
            anchors.right: parent.right
            spacing: 6
            Btn { text: "−"; onClicked: st.changedTo(st.value - 1) }
            Label { width: 64; height: 26; horizontalAlignment: Text.AlignHCenter; text: st.value + (st.unit ? " " + st.unit : ""); strong: true; color: Theme.bright }
            Btn { text: "+"; onClicked: st.changedTo(st.value + 1) }
        }
    }
}
