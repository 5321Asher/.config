import QtQuick
import QtQuick.Effects
import "../theme"
import "../services"
import "../deck"

// Signal beacons hanging off the horizon line, visible whether the bar is open or not:
//   recording   a pulsing signal-red diamond, "rec" and the elapsed time; click to stop
//   chronometer a phosphor ring, the phase and the time left; click for the chronometer page
Row {
    id: root

    spacing: 18
    visible: rec.visible || chrono.visible

    Beacon {
        id: rec
        visible: Capture.recording
        ink: Theme.signal
        diamond: true
        label: "rec"
        value: Capture.elapsedText
        hint: "click to stop"
        onClicked: Capture.toggleRecording()
    }
    Beacon {
        id: chrono
        visible: FocusTimer.active
        ink: FocusTimer.mode === "pomodoro" && FocusTimer.phase !== "focus" ? Theme.phosphor : Theme.brassBright
        pulse: FocusTimer.running
        label: FocusTimer.phaseLabel.toLowerCase()
        value: FocusTimer.remainingText + (FocusTimer.running ? "" : " · paused")
        hint: "chronometer"
        onClicked: DeckState.toggleTo("chronometer")
    }

    component Beacon: Item {
        id: b
        property color ink
        property bool diamond: false
        property bool pulse: true
        property string label
        property string value
        property string hint
        signal clicked()
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        Row {
            id: row
            spacing: 8
            Item {
                width: 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: b.diamond ? 8 : 10
                    height: width
                    rotation: b.diamond ? 45 : 0
                    radius: b.diamond ? 0 : width / 2
                    color: b.diamond ? b.ink : "transparent"
                    border.width: b.diamond ? 0 : 1.5
                    border.color: b.ink
                    SequentialAnimation on opacity {
                        running: b.visible && b.pulse
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                    }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: b.ink; shadowBlur: 0.8; shadowOpacity: 1
                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: b.label
                color: b.ink
                font.family: Theme.fontLabel
                font.pixelSize: Theme.labelSize
                font.capitalization: Font.SmallCaps
                font.letterSpacing: Theme.labelSpacing
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: b.value
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: b.hint
                color: Theme.dim
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
                opacity: mouse.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }
}
