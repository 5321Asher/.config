import QtQuick
import QtQuick.Effects
import "../theme"
import "../widgets"

// One card of the arcana, face up: black leather, and stamped on it in gold foil (shaders/foil.frag)
// a double rule, the numeral, the emblem in its ring, the name and a line under it. The foil catches
// the light where the pointer is; the chosen card catches it most.
Item {
    id: root

    property var card: ({})
    property bool chosen: false
    property point light: Qt.point(0.25, 0.2)

    // a soft shadow on the desk, deeper when the card is lifted
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.chosen ? 18 : 8
        anchors.leftMargin: root.chosen ? 4 : 2
        anchors.rightMargin: root.chosen ? -8 : -3
        anchors.bottomMargin: root.chosen ? -22 : -8
        radius: 12
        color: Qt.alpha("#000000", root.chosen ? 0.6 : 0.5)
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 32 }
    }

    Leather {
        anchors.fill: parent
        radius: 11
        tooled: false
        color: Theme.mix(Theme.leatherDark, "#000000", 0.35)
        seed: 0.13 + root.x * 0.001
    }
    // a warm edge, as if lit from the candle
    Rectangle {
        anchors.fill: parent
        radius: 11
        color: "transparent"
        border.width: 1
        border.color: Theme.alpha(Theme.goldDeep, root.chosen ? 0.9 : 0.55)
    }

    // ---------------------------------------------------------------- the gold, as a stencil
    Item {
        id: art
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 4

        Rectangle { anchors.fill: parent; anchors.margins: 9; radius: 6; color: "transparent"; border.width: 1.3; border.color: "white" }
        Rectangle { anchors.fill: parent; anchors.margins: 13; radius: 4; color: "transparent"; border.width: 0.8; border.color: "white" }
        Repeater {
            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
            Text {
                required property var modelData
                x: modelData[0] ? art.width - 13 - width / 2 : 13 - width / 2
                y: modelData[1] ? art.height - 13 - height / 2 : 13 - height / 2
                text: "◆"; color: "white"; font.pixelSize: 8
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.height * 0.075
            text: root.card.numeral ?? ""
            color: "white"
            font.family: Theme.caps
            font.pixelSize: Math.round(art.width * 0.085)
            font.letterSpacing: 3
            font.weight: Font.DemiBold
        }

        Item {
            id: medallion
            width: art.width * 0.7
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.height * 0.2
            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1.1; border.color: "white" }
            Rectangle { anchors.fill: parent; anchors.margins: 5; radius: width / 2; color: "transparent"; border.width: 0.6; border.color: "white" }
            Emblem {
                anchors.centerIn: parent
                width: parent.width * 0.64
                height: width
                kind: root.card.emblem ?? "sigil"
                stroke: 1.5
            }
        }

        Text {
            id: name
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.height * 0.735
            width: art.width - 36
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.card.title ?? ""
            color: "white"
            font.family: Theme.caps
            font.pixelSize: Math.round(art.width * 0.1)
            font.letterSpacing: 2
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: name.bottom
            anchors.topMargin: 2
            width: art.width - 40
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.card.sub_text ?? ""
            color: "white"
            opacity: 0.75
            font.family: Theme.body
            font.italic: true
            font.pixelSize: Math.round(art.width * 0.068)
        }
    }

    // ---------------------------------------------------------------- stamped in foil
    ShaderEffect {
        anchors.fill: parent
        property var source: art
        property point light: root.light
        property real shine: root.chosen ? 1 : 0.25
        property color gold: Theme.gold
        property color goldBright: Theme.goldBright
        property color goldDeep: Theme.goldDeep
        fragmentShader: Theme.shaders + "foil.frag.qsb"
        Behavior on shine { NumberAnimation { duration: Theme.normal } }
    }
}
