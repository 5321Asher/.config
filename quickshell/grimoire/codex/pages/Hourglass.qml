import QtQuick
import QtQuick.Shapes
import "../../theme"
import "../../widgets"
import "../../services"

// X. Hourglass: the focus timer: pomodoro (focus, a short rest, a long rest every few rounds) or a
// plain countdown. An hourglass drawn on the page empties as it runs, the time under it in uncials;
// the bar shows it while it runs.
Column {
    id: root

    spacing: 20

    Row {
        spacing: 8
        Btn { text: "pomodoro"; on: FocusTimer.mode === "pomodoro"; onClicked: FocusTimer.setMode("pomodoro") }
        Btn { text: "countdown"; on: FocusTimer.mode === "timer"; onClicked: FocusTimer.setMode("timer") }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 30
        // the glass
        Item {
            id: glass
            width: 80; height: 130
            readonly property real sand: FocusTimer.progress             // sand still above (progress = the part remaining)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // sand above: a triangle shrinking toward the neck
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Theme.goldDeep
                    PathSvg { path: { const k = Math.sqrt(glass.sand), h = 50 * k; return `M ${40 - 30 * k} ${60 - h} L ${40 + 30 * k} ${60 - h} L 40 63 Z`; } }
                }
                // sand below: a heap growing
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Theme.goldDeep
                    PathSvg { path: `M 10 120 L 40 ${120 - 44 * Math.sqrt(1 - glass.sand)} L 70 120 Z` }
                }
                // the glass
                ShapePath {
                    strokeColor: Theme.ink
                    strokeWidth: 1.6
                    fillColor: Theme.alpha("#ffffff", 0.12)
                    PathSvg { path: "M 8 8 L 72 8 C 72 40 46 52 44 65 C 46 78 72 90 72 122 L 8 122 C 8 90 34 78 36 65 C 34 52 8 40 8 8 Z" }
                }
                // the frame
                ShapePath {
                    strokeColor: Theme.goldDeep
                    strokeWidth: 5
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: "M 2 4 L 78 4 M 2 126 L 78 126" }
                }
            }
            // the falling thread of sand
            Rectangle { visible: FocusTimer.running; x: 39; y: 63; width: 2; height: 56 - 44 * Math.sqrt(1 - glass.sand); color: Theme.goldDeep }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                text: FocusTimer.remainingText
                color: FocusTimer.running ? Theme.ink : Theme.inkDim
                font.family: Theme.display; font.weight: Font.DemiBold
                font.pixelSize: 62
            }
            Body {
                text: FocusTimer.phaseLabel.toLowerCase() + (FocusTimer.mode === "pomodoro" ? " · round " + Math.min(FocusTimer.rounds, FocusTimer.completed + 1) + " of " + FocusTimer.rounds : "")
                      + (FocusTimer.running ? "" : FocusTimer.active ? " · paused" : "")
                italic: true
                color: FocusTimer.running ? Theme.rubric : Theme.inkDim
            }
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        Btn { text: FocusTimer.running ? "pause" : FocusTimer.active ? "resume" : "turn the glass"; primary: true; onClicked: FocusTimer.toggle() }
        Btn { text: "reset"; enabled: FocusTimer.active; onClicked: FocusTimer.reset() }
        Btn { text: FocusTimer.mode === "pomodoro" ? "skip" : "restart"; onClicked: FocusTimer.skip() }
    }

    Section {
        visible: FocusTimer.mode === "pomodoro"
        title: "the rounds"
        Stepper { label: "focus"; value: FocusTimer.focusMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("focus", v) }
        Stepper { label: "a short rest"; value: FocusTimer.shortMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("short", v) }
        Stepper { label: "a long rest"; value: FocusTimer.longMins; unit: "min"; onChangedTo: v => FocusTimer.setPhaseMins("long", v) }
        Stepper { label: "rounds"; value: FocusTimer.rounds; unit: ""; onChangedTo: v => FocusTimer.rounds = Math.max(1, Math.min(12, v)) }
        Row { spacing: 10; Seal { checked: FocusTimer.autoStart; onToggled: FocusTimer.autoStart = !FocusTimer.autoStart }
              Body { anchors.verticalCenter: parent.verticalCenter; text: "turn the glass again by itself"; italic: true } }
    }
    Section {
        visible: FocusTimer.mode === "timer"
        title: "the countdown"
        Stepper { label: "length"; value: FocusTimer.timerMins; unit: "min"; onChangedTo: v => FocusTimer.setTimerMins(v) }
        Flow {
            width: parent.width
            spacing: 6
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
        height: 30
        Body { anchors.verticalCenter: parent.verticalCenter; text: st.label; italic: true }
        Row {
            anchors.right: parent.right
            spacing: 6
            Btn { text: "−"; onClicked: st.changedTo(st.value - 1) }
            Body { width: 70; height: 28; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter; text: st.value + (st.unit ? " " + st.unit : ""); strong: true }
            Btn { text: "+"; onClicked: st.changedTo(st.value + 1) }
        }
    }
}
