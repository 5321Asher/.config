import QtQuick
import QtQuick.Effects
import "../theme"
import "../widgets"

// One card of the arcana, face up: the theme's leather over a board, and pressed into it in gilt a
// double rule, the numeral, the emblem in its ring, the name and a line under it. The pointer is
// the light, so the gilt catches it as you move; the chosen card is lit most.
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

    // ---------------------------------------------------------------- the card: lit leather, tooled
    // (widgets/Cover.qml: the theme's leather over a board with rounded, rubbed edges, everything on
    // it pressed in gilt). The pointer is the light: the gold catches it as you move across the card.
    Cover {
        id: face
        anchors.fill: parent
        radius: 11
        bevel: 9
        wear: 0.55
        seed: 0.13 + root.x * 0.001
        color: Theme.leather
        light: Qt.vector3d(root.light.x * width, root.light.y * height, root.chosen ? 260 : 520)
        lightPower: root.chosen ? 1.5 : 1.1
        ambient: root.chosen ? 0.7 : 0.55
        lightColor: Theme.mix(Theme.flame, "#ffffff", 0.55)
    Item {
        id: art
        anchors.fill: parent

        Rectangle { anchors.fill: parent; anchors.margins: 9; radius: 6; color: "transparent"; border.width: 1.3; border.color: face.gilt }
        Rectangle { anchors.fill: parent; anchors.margins: 13; radius: 4; color: "transparent"; border.width: 0.8; border.color: face.gilt }
        Repeater {
            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
            Text {
                required property var modelData
                x: modelData[0] ? art.width - 13 - width / 2 : 13 - width / 2
                y: modelData[1] ? art.height - 13 - height / 2 : 13 - height / 2
                text: "◆"; color: face.gilt; font.pixelSize: 8
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.height * 0.075
            text: root.card.numeral ?? ""
            color: face.gilt
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
            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1.1; border.color: face.gilt }
            Rectangle { anchors.fill: parent; anchors.margins: 5; radius: width / 2; color: "transparent"; border.width: 0.6; border.color: face.gilt }
            Emblem {
                anchors.centerIn: parent
                width: parent.width * 0.64
                height: width
                kind: root.card.emblem ?? "sigil"
                stroke: 1.8
                color: face.gilt
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
            color: face.gilt
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
            color: face.gilt
            font.family: Theme.body
            font.italic: true
            font.pixelSize: Math.round(art.width * 0.068)
        }
    }
    }
    // a hairline of shadow round the edge, lifting it off the desk
    Rectangle {
        anchors.fill: parent
        radius: 11
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha("#000000", 0.45)
    }
}
