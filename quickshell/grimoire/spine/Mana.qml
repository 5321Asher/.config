import QtQuick
import QtQuick.Effects
import "../theme"

// The mana bar: the battery as a tall glass capsule of glowing mana, filled to the charge. Motes
// drift up through it; while charging, a brighter band flows up the tube; below 20% it turns red
// and pulses. Without a battery (on the ley line: mains power) it stands full and still.
Item {
    id: root

    property real value: 1              // 0..1
    property bool charging: false
    property bool present: true
    readonly property bool low: present && value < 0.2 && !charging
    readonly property color mana: low ? Theme.danger : Theme.mix(Theme.arcane, "#6fa8ff", 0.25)

    implicitWidth: 18
    implicitHeight: 104

    // the glass
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.alpha(Theme.leatherDark, 0.7)
        border.width: 1
        border.color: Theme.alpha(Theme.light ? Theme.ink : Theme.fg, 0.45)
    }
    // the mana
    Item {
        id: fill
        x: 3; width: parent.width - 6
        readonly property real full: parent.height - 6
        height: full * Math.max(0.03, Math.min(1, root.value))
        y: 3 + full - height
        Behavior on height { NumberAnimation { duration: Theme.stately; easing.type: Theme.easing } }
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.mana
            shadowBlur: 0.6
            shadowOpacity: root.low ? 0.4 + pulse.v * 0.5 : 0.6
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 14
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(root.mana, 1.5) }
                GradientStop { position: 1; color: Qt.darker(root.mana, 1.4) }
            }
        }
        // charging: a band of light flowing upward
        Rectangle {
            visible: root.charging
            width: parent.width
            height: 26
            y: parent.height - flow.p * (parent.height + 26)
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Theme.alpha("#ffffff", 0.55) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        // motes
        Repeater {
            model: root.present ? 5 : 0
            Rectangle {
                id: mote
                required property int index
                width: 2; height: 2; radius: 1
                color: "#ffffff"
                x: 2 + (index * 5) % (fill.width - 4)
                property real p: (index * 0.21) % 1
                y: fill.height - p * fill.height
                opacity: 0.8 * (1 - p)
                NumberAnimation on p { from: 0; to: 1; duration: 3400 + mote.index * 610; loops: Animation.Infinite }
            }
        }
    }
    // tick marks on the glass
    Repeater {
        model: 3
        Rectangle { required property int index; x: parent.width - 5; y: parent.height * (index + 1) / 4; width: 4; height: 1
                    color: Theme.alpha(Theme.light ? Theme.ink : Theme.fg, 0.35) }
    }
    // highlight
    Rectangle { x: 4; y: 6; width: 2; height: parent.height - 12; radius: 1; color: Theme.alpha("#ffffff", 0.22) }

    QtObject { id: pulse; property real v: 0 }
    QtObject { id: flow; property real p: 0 }
    SequentialAnimation {
        running: root.low
        loops: Animation.Infinite
        NumberAnimation { target: pulse; property: "v"; to: 1; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: pulse; property: "v"; to: 0; duration: 700; easing.type: Easing.InOutSine }
    }
    Timer { running: root.charging; repeat: true; interval: 40; onTriggered: { flow.p = (flow.p + 0.012) % 1; } }
}
