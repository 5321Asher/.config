import QtQuick
import "../theme"

// An illuminated capital: a square of gold leaf, framed in ink, with a vine in the corners and the
// letter in blackletter, in wax red. For page titles and the letters' openings.
Item {
    id: root

    property string letter: "A"
    property real size: 52
    property color letterColor: Theme.rubric

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: 2
        border.width: 1
        border.color: Theme.ink
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.goldBright }
            GradientStop { position: 0.55; color: Theme.gold }
            GradientStop { position: 1; color: Theme.goldDeep }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        color: "transparent"
        border.width: 1
        border.color: Theme.alpha(Theme.ink, 0.5)
    }
    // the vine
    Repeater {
        model: ["tl", "tr", "bl", "br"]
        Flourish {
            required property string modelData
            corner: modelData
            size: root.size * 0.42
            stroke: 1
            color: Theme.alpha(Theme.ink, 0.55)
            shade: "transparent"
            x: modelData.endsWith("l") ? 4 : root.size - width - 4
            y: modelData.startsWith("t") ? 4 : root.size - height - 4
        }
    }
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.size * 0.04
        text: root.letter
        color: root.letterColor
        style: Text.Outline
        styleColor: Theme.alpha(Theme.goldBright, 0.6)
        font.family: Theme.blackletter
        font.pixelSize: root.size * 0.78
    }
}
