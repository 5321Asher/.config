import QtQuick
import QtQuick.Effects
import "../theme"
import "../services"

// Signal beacons hanging off the horizon line, visible whether the bar is open or not.
// Recording: a pulsing signal-red diamond, "rec" and the elapsed time; click it to stop.
Item {
    id: root

    visible: Capture.recording
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
                width: 8
                height: 8
                rotation: 45
                color: Theme.signal
                SequentialAnimation on opacity {
                    running: Capture.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: Theme.signal; shadowBlur: 0.8; shadowOpacity: 1
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "rec"
            color: Theme.signal
            font.family: Theme.fontLabel
            font.pixelSize: Theme.labelSize
            font.capitalization: Font.SmallCaps
            font.letterSpacing: Theme.labelSpacing
            font.weight: Font.DemiBold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Capture.elapsedText
            color: Theme.fg
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "click to stop"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
            opacity: stopMouse.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        }

    }

    MouseArea {
        id: stopMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Capture.toggleRecording()
    }
}
