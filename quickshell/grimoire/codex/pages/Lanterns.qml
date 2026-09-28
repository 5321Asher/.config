import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"

// IX. Lanterns: coloured light through OpenRGB. A strip of hues and one of lightness, a few
// candlelit presets, set every lantern or one at a time (with its mode), follow the theme's gold,
// and profiles to keep and recall.
Column {
    id: root

    spacing: 22
    Component.onCompleted: if (!Rgb.scanned) Rgb.scan()

    property real hue: 0.11
    property real light: 0.55
    readonly property color picked: Qt.hsla(hue, 0.9, light, 1)
    function pick(c) { const q = Qt.color(c); hue = Math.max(0, q.hslHue); light = q.hslLightness; }

    Body { visible: Rgb.scanned && !Rgb.available; width: parent.width; wrapMode: Text.Wrap; italic: true; color: Theme.inkDim
           text: "No lanterns answer (openrgb isn't installed, or found nothing). Install openrgb, and load i2c-dev for the board's and memory's lights." }

    Section {
        visible: Rgb.available || !Rgb.scanned
        title: "the colour"
        trailing: Rgb.busy ? "kindling…" : Rgb.devices.length + " lanterns"
        Row {
            spacing: 16
            Item {
                width: 70; height: 70
                Rectangle { anchors.fill: parent; radius: 35; color: root.picked; border.width: 3; border.color: Theme.gold }
                Rectangle { anchors.fill: parent; anchors.margins: -6; radius: 41; color: "transparent"; border.width: 1; border.color: Theme.alpha(root.picked, 0.5) }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Body { text: "#" + Rgb.hex(root.picked); strong: true }
                Flow {
                    width: root.width - 100
                    spacing: 8
                    Repeater {
                        model: ["#ffb04a", "#ff7b3a", "#c9a24a", "#9b7fe0", "#5fd6b4", "#7fb8f0", "#c4453a", "#fff4e0"]
                        Rectangle { required property string modelData; width: 22; height: 22; radius: 11; color: modelData
                                    border.width: Qt.color(modelData).toString() === root.picked.toString() ? 2 : 1
                                    border.color: Qt.color(modelData).toString() === root.picked.toString() ? Theme.ink : Theme.alpha(Theme.ink, 0.3)
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(parent.modelData) } }
                    }
                }
            }
        }
        Item {
            width: parent.width; height: 18
            Rectangle {
                anchors.fill: parent; radius: 3; border.width: 1; border.color: Theme.alpha(Theme.ink, 0.3)
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ff0000" } GradientStop { position: 0.17; color: "#ffff00" }
                    GradientStop { position: 0.33; color: "#00ff00" } GradientStop { position: 0.5; color: "#00ffff" }
                    GradientStop { position: 0.67; color: "#0000ff" } GradientStop { position: 0.83; color: "#ff00ff" }
                    GradientStop { position: 1; color: "#ff0000" } }
            }
            Rectangle { x: root.hue * parent.width - 5; y: -3; width: 10; height: parent.height + 6; radius: 2; color: "transparent"; border.width: 2; border.color: Theme.ink }
            MouseArea { anchors.fill: parent; onPressed: e => root.hue = Math.max(0, Math.min(0.999, e.x / width))
                        onPositionChanged: e => { if (pressed) root.hue = Math.max(0, Math.min(0.999, e.x / width)); } }
        }
        Item {
            width: parent.width; height: 12
            Rectangle { anchors.fill: parent; radius: 3; border.width: 1; border.color: Theme.alpha(Theme.ink, 0.3)
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#000000" } GradientStop { position: 0.5; color: Qt.hsla(root.hue, 0.9, 0.5, 1) }
                    GradientStop { position: 1; color: "#ffffff" } } }
            Rectangle { x: root.light * parent.width - 5; y: -3; width: 10; height: parent.height + 6; radius: 2; color: "transparent"; border.width: 2; border.color: Theme.ink }
            MouseArea { anchors.fill: parent; onPressed: e => root.light = Math.max(0, Math.min(1, e.x / width))
                        onPositionChanged: e => { if (pressed) root.light = Math.max(0, Math.min(1, e.x / width)); } }
        }
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: "light them all"; primary: true; enabled: !Rgb.busy && Rgb.devices.length > 0; onClicked: Rgb.setAll(root.picked) }
            Btn { text: "snuff them"; enabled: !Rgb.busy; onClicked: Rgb.setAll("#000000") }
            Btn { text: "look again"; enabled: !Rgb.busy; onClicked: Rgb.scan() }
        }
        Row {
            spacing: 10
            Seal { checked: Rgb.followWallpaper; onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper) }
            Body { anchors.verticalCenter: parent.verticalCenter; text: "follow the theme's gold"; italic: true }
        }
        Body { visible: Rgb.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Rgb.error; color: Theme.danger; italic: true }
    }

    Section {
        visible: Rgb.available
        title: "each lantern"
        Repeater {
            model: Rgb.devices
            Column {
                id: dev
                required property var modelData
                property string mode: modelData.mode || Rgb.colorMode(modelData)
                width: parent.width
                spacing: 6
                Row2 {
                    glyph: "\u{f0335}"
                    title: dev.modelData.name
                    subtitle: dev.modelData.type
                    Btn { text: "light"; enabled: !Rgb.busy; onClicked: Rgb.setDevice(dev.modelData, dev.mode, root.picked) }
                }
                Flow {
                    x: 36
                    width: parent.width - 36
                    spacing: 4
                    Repeater { model: dev.modelData.modes
                        Btn { required property var modelData; text: modelData; on: dev.mode === modelData; onClicked: dev.mode = modelData } }
                }
            }
        }
    }

    Section {
        visible: Rgb.available
        title: "kept lights"
        Flow {
            width: parent.width
            spacing: 6
            Repeater { model: Rgb.profiles; Btn { required property string modelData; text: modelData; enabled: !Rgb.busy; onClicked: Rgb.loadProfile(modelData) } }
        }
        Body { visible: Rgb.profiles.length === 0; text: "None kept yet."; italic: true; color: Theme.inkDim }
        Row {
            spacing: 8
            Field { id: profName; width: 220; placeholder: "a name for these lights"; onAccepted: if (text.trim()) { Rgb.saveProfile(text.trim()); text = ""; } }
            Btn { text: "keep"; enabled: !Rgb.busy && profName.text.trim() !== ""; onClicked: { Rgb.saveProfile(profName.text.trim()); profName.text = ""; } }
        }
    }
}
