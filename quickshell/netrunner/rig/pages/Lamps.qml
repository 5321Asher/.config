import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"

// 09 LAMPS 照明: RGB lighting through OpenRGB. A hue strip and a lightness strip, the neon
// presets, apply to everything or per device (with its mode); follow the profile's accent;
// profiles to load and save.
Column {
    id: root

    spacing: 22
    Component.onCompleted: if (!Rgb.scanned) Rgb.scan()

    property real hue: 0.98
    property real light: 0.5
    readonly property color picked: Qt.hsla(hue, 1, light, 1)
    function pick(c) { const q = Qt.color(c); hue = Math.max(0, q.hslHue); light = q.hslLightness; }

    Label { visible: Rgb.scanned && !Rgb.available; width: parent.width; wrapMode: Text.Wrap; color: Theme.yellow
            text: "openrgb not found (or no devices): install openrgb and load i2c-dev for motherboard / ram lighting" }

    Section {
        visible: Rgb.available || !Rgb.scanned
        title: "colour"
        jp: "色"
        trailing: Rgb.busy ? "writing…" : Rgb.devices.length + " devices"
        Row {
            spacing: 14
            Item {
                width: 70; height: 70
                Chamfer { anchors.fill: parent; cut: 10; corners: "tr bl"; fill: root.picked; stroke: Theme.bright }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Label { text: "#" + Rgb.hex(root.picked); strong: true; color: Theme.bright }
                Flow {
                    width: root.width - 90
                    spacing: 6
                    Repeater {
                        model: ["#ff2a3d", "#00f0ff", "#fcee0a", "#ff00a0", "#7a00ff", "#00ff9c", "#ffffff"]
                        Rectangle { required property string modelData; width: 22; height: 22; color: modelData
                                    border.width: Qt.color(modelData).toString() === root.picked.toString() ? 2 : 0; border.color: Theme.bright
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(parent.modelData) } }
                    }
                }
            }
        }
        // hue
        Item {
            width: parent.width; height: 18
            Rectangle {
                anchors.fill: parent
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ff0000" } GradientStop { position: 0.17; color: "#ffff00" }
                    GradientStop { position: 0.33; color: "#00ff00" } GradientStop { position: 0.5; color: "#00ffff" }
                    GradientStop { position: 0.67; color: "#0000ff" } GradientStop { position: 0.83; color: "#ff00ff" }
                    GradientStop { position: 1; color: "#ff0000" } }
            }
            Rectangle { x: root.hue * parent.width - 2; width: 4; height: parent.height + 6; y: -3; color: Theme.bright }
            MouseArea { anchors.fill: parent; onPressed: e => root.hue = Math.max(0, Math.min(0.999, e.x / width))
                        onPositionChanged: e => { if (pressed) root.hue = Math.max(0, Math.min(0.999, e.x / width)); } }
        }
        // lightness
        Item {
            width: parent.width; height: 12
            Rectangle { anchors.fill: parent
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#000000" } GradientStop { position: 0.5; color: Qt.hsla(root.hue, 1, 0.5, 1) }
                    GradientStop { position: 1; color: "#ffffff" } } }
            Rectangle { x: root.light * parent.width - 2; width: 4; height: parent.height + 6; y: -3; color: Theme.bright }
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
            Label { anchors.verticalCenter: parent.verticalCenter; text: "follow the profile's accent" }
        }
        Label { visible: Rgb.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Rgb.error; color: Theme.red }
    }

    Section {
        visible: Rgb.available
        title: "devices"
        jp: "機器"
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
        jp: "設定"
        Flow {
            width: parent.width
            spacing: 6
            Repeater { model: Rgb.profiles; Btn { required property string modelData; text: modelData; enabled: !Rgb.busy; onClicked: Rgb.loadProfile(modelData) } }
        }
        Label { visible: Rgb.profiles.length === 0; text: "// no saved profiles" }
        Row {
            spacing: 8
            Field { id: profName; width: 220; placeholder: "profile name"; onAccepted: if (text.trim()) { Rgb.saveProfile(text.trim()); text = ""; } }
            Btn { text: "save"; enabled: !Rgb.busy && profName.text.trim() !== ""; onClicked: { Rgb.saveProfile(profName.text.trim()); profName.text = ""; } }
        }
    }
}
