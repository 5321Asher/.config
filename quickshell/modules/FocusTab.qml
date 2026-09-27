import QtQuick
import QtQuick.Layouts

// Pomodoro / countdown timer
Flickable {
    id: root

    readonly property bool pomodoro: FocusTimer.mode === "pomodoro"
    readonly property color phaseColor: !pomodoro || FocusTimer.phase === "focus" ? Theme.accent : Theme.green

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content

        width: root.width
        spacing: 12

        // Mode switcher
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            IconButton {
                Layout.fillWidth: true
                icon: root.glyph(0xF051F)
                label: "Pomodoro"
                primary: root.pomodoro
                onClicked: FocusTimer.setMode("pomodoro")
            }

            IconButton {
                Layout.fillWidth: true
                icon: root.glyph(0xF051B)
                label: "Timer"
                primary: !root.pomodoro
                onClicked: FocusTimer.setMode("timer")
            }
        }

        // Dial + controls
        Card {
            spacing: 18

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 230
                implicitHeight: 230

                // Soft glow while running
                Rectangle {
                    anchors.centerIn: parent
                    width: 200
                    height: 200
                    radius: 0
                    color: root.phaseColor
                    opacity: FocusTimer.running ? 0.08 : 0

                    Behavior on opacity { NumberAnimation { duration: 400 } }
                }

                Ring {
                    anchors.fill: parent
                    value: FocusTimer.progress
                    color: root.phaseColor
                    thickness: 12

                    Behavior on value {
                        enabled: FocusTimer.running
                        NumberAnimation { duration: 250 }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: FocusTimer.phaseLabel.toUpperCase()
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 3
                        color: root.phaseColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: FocusTimer.remainingText
                        font.family: Theme.font
                        font.pixelSize: 48
                        font.bold: true
                        color: Theme.fg
                    }

                    // Rounds completed
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.pomodoro
                        spacing: 6

                        Repeater {
                            model: FocusTimer.rounds

                            Rectangle {
                                required property int index
                                width: 8
                                height: 8
                                radius: 0
                                color: index < FocusTimer.completed ? Theme.accent : Theme.border
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !FocusTimer.running && FocusTimer.active
                        text: "Paused"
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.dim
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                RoundButton {
                    icon: root.glyph(0xF0709)
                    size: 44
                    enabled: FocusTimer.active
                    onClicked: FocusTimer.reset()
                }

                RoundButton {
                    icon: root.glyph(FocusTimer.running ? 0xF03E4 : 0xF040A)
                    size: 64
                    primary: true
                    tint: root.phaseColor
                    onClicked: FocusTimer.toggle()
                }

                RoundButton {
                    icon: root.glyph(0xF04AD)
                    size: 44
                    onClicked: FocusTimer.skip()
                }
            }
        }

        // Pomodoro lengths
        Card {
            visible: root.pomodoro
            title: "Session lengths"
            spacing: 10

            Stepper {
                label: "Focus"
                value: FocusTimer.focusMins
                suffix: " min"
                onStepped: v => FocusTimer.setPhaseMins("focus", v)
            }
            Stepper {
                label: "Short break"
                value: FocusTimer.shortMins
                suffix: " min"
                onStepped: v => FocusTimer.setPhaseMins("short", v)
            }
            Stepper {
                label: "Long break"
                value: FocusTimer.longMins
                suffix: " min"
                onStepped: v => FocusTimer.setPhaseMins("long", v)
            }
            Stepper {
                label: "Rounds before long break"
                value: FocusTimer.rounds
                step: 1
                onStepped: v => FocusTimer.rounds = Math.max(1, Math.min(12, v))
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Start next session automatically"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.fg
                }

                Switch {
                    checked: FocusTimer.autoStart
                    onToggled: FocusTimer.autoStart = !FocusTimer.autoStart
                }
            }
        }

        // Timer presets
        Card {
            visible: !root.pomodoro
            title: "Length"
            spacing: 12

            Stepper {
                label: "Minutes"
                value: FocusTimer.timerMins
                enabled: !FocusTimer.running
                onStepped: v => FocusTimer.setTimerMins(v)
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [1, 3, 5, 10, 15, 20, 30, 45, 60, 90]

                    IconButton {
                        required property int modelData
                        label: modelData >= 60 ? Math.floor(modelData / 60) + "h" + (modelData % 60 ? " " + modelData % 60 + "m" : "") : modelData + "m"
                        primary: FocusTimer.timerMins === modelData
                        enabled: !FocusTimer.running
                        onClicked: FocusTimer.setTimerMins(modelData)
                    }
                }
            }
        }
    }

    component RoundButton: Rectangle {
        id: rb

        property string icon
        property int size: 44
        property bool primary: false
        property color tint: Theme.accent
        signal clicked

        implicitWidth: size
        implicitHeight: size
        radius: 0
        opacity: enabled ? 1 : 0.35
        color: primary || rbMouse.containsMouse ? Theme.surface : Theme.hover
        border.width: primary ? 1 : 0
        border.color: tint
        scale: rbMouse.pressed ? 0.93 : 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 90 } }

        Text {
            anchors.centerIn: parent
            text: rb.icon
            font.family: Theme.font
            font.pixelSize: rb.primary ? 26 : 18
            color: rb.primary ? rb.tint : Theme.fg
        }

        MouseArea {
            id: rbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }

    component Stepper: RowLayout {
        id: st

        property string label
        property int value
        property int step: 1
        property string suffix
        signal stepped(int value)

        Layout.fillWidth: true
        opacity: enabled ? 1 : 0.4
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: st.label
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.fg
        }

        IconButton {
            icon: root.glyph(0xF0374)
            onClicked: st.stepped(st.value - st.step)
        }

        Text {
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignHCenter
            text: st.value + st.suffix
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
            color: Theme.fg
        }

        IconButton {
            icon: root.glyph(0xF0415)
            onClicked: st.stepped(st.value + st.step)
        }
    }
}
