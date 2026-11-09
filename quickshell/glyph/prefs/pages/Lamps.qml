import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"

// LIGHTS: RGB lighting through OpenRGB. A hue strip and a lightness strip, presets (Nothing's red and
// white first), apply to everything or per device (with its mode); follow the theme; profiles.
Column {
    id: root

    spacing: 34
    Component.onCompleted: if (!Rgb.scanned) Rgb.scan()

    property real hue: 0.98
    property real light: 0.5
    readonly property color picked: Qt.hsla(hue, 1, light, 1)
    function pick(c) { const q = Qt.color(c); hue = Math.max(0, q.hslHue); light = q.hslLightness; }

    Lb { visible: Rgb.scanned && !Rgb.available; width: parent.width; wrapMode: Text.Wrap; color: Theme.yellow
            text: "openrgb not found (or no devices): install openrgb and load i2c-dev for motherboard / ram lighting" }

    Section {
        visible: Rgb.available || !Rgb.scanned
        title: "colour"
        
        trailing: Rgb.busy ? "writing…" : Rgb.devices.length + " devices"
        Row {
            spacing: 14
            Item {
                width: 70; height: 70
                Rectangle { anchors.fill: parent; radius: 35; color: root.picked; border { width: 1; color: Theme.s3 } }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Num { text: "#" + Rgb.hex(root.picked); font.pixelSize: 34 }
                Flow {
                    width: root.width - 90
                    spacing: 6
                    Repeater {
                        model: ["#d71921", "#ffffff", "#ff6a00", "#fcee0a", "#00ff9c", "#00b4ff", "#7a00ff"]
                        Rectangle { required property string modelData; width: 30; height: 30; radius: 15; color: modelData
                                    border.width: Qt.color(modelData).toString() === root.picked.toString() ? 2 : 0; border.color: Theme.bright
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(parent.modelData) } }
                    }
                }
            }
        }
        // hue
        Item {
            width: parent.width; height: 22
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ff0000" } GradientStop { position: 0.17; color: "#ffff00" }
                    GradientStop { position: 0.33; color: "#00ff00" } GradientStop { position: 0.5; color: "#00ffff" }
                    GradientStop { position: 0.67; color: "#0000ff" } GradientStop { position: 0.83; color: "#ff00ff" }
                    GradientStop { position: 1; color: "#ff0000" } }
            }
            Rectangle { x: root.hue * parent.width - 12; width: 24; height: 24; radius: 12; y: (parent.height - 24) / 2; color: Theme.fg; border { width: 3; color: Theme.s1 } }
            MouseArea { anchors.fill: parent; onPressed: e => root.hue = Math.max(0, Math.min(0.999, e.x / width))
                        onPositionChanged: e => { if (pressed) root.hue = Math.max(0, Math.min(0.999, e.x / width)); } }
        }
        // lightness
        Item {
            width: parent.width; height: 22
            Rectangle { anchors.fill: parent; radius: height / 2
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#000000" } GradientStop { position: 0.5; color: Qt.hsla(root.hue, 1, 0.5, 1) }
                    GradientStop { position: 1; color: "#ffffff" } } }
            Rectangle { x: root.light * parent.width - 12; width: 24; height: 24; radius: 12; y: (parent.height - 24) / 2; color: Theme.fg; border { width: 3; color: Theme.s1 } }
            MouseArea { anchors.fill: parent; onPressed: e => root.light = Math.max(0, Math.min(1, e.x / width))
                        onPositionChanged: e => { if (pressed) root.light = Math.max(0, Math.min(1, e.x / width)); } }
        }
        Flow {
            width: parent.width
            spacing: 8
            Btn { text: "apply to all"; primary: true; enabled: !Rgb.busy && Rgb.devices.length > 0; onClicked: Rgb.setAll(root.picked) }
            Btn { text: "lights off"; enabled: !Rgb.busy; onClicked: Rgb.setAll("#000000") }
            Btn { text: "rescan"; enabled: !Rgb.busy; onClicked: Rgb.scan() }
        }
        Row {
            spacing: 10
            Switch { checked: Rgb.followWallpaper; onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper) }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: "follow the theme" }
        }
        Lb { visible: Rgb.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Rgb.error; color: Theme.red }
    }

    Section {
        visible: Rgb.available
        title: "devices"
        
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
                    Btn { text: "set"; enabled: !Rgb.busy; onClicked: Rgb.setDevice(dev.modelData, dev.mode, root.picked) }
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
        title: "profiles"
        
        Flow {
            width: parent.width
            spacing: 6
            Repeater { model: Rgb.profiles; Btn { required property string modelData; text: modelData; enabled: !Rgb.busy; onClicked: Rgb.loadProfile(modelData) } }
        }
        Lb { visible: Rgb.profiles.length === 0; text: "no saved profiles" }
        Row {
            spacing: 8
            Field { id: profName; width: 220; placeholder: "profile name"; onAccepted: if (text.trim()) { Rgb.saveProfile(text.trim()); text = ""; } }
            Btn { text: "save"; enabled: !Rgb.busy && profName.text.trim() !== ""; onClicked: { Rgb.saveProfile(profName.text.trim()); profName.text = ""; } }
        }
    }
}
