import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Dynamic Lighting (OpenRGB): follow the theme's accent, or pick a colour for every device; each
// device's effect; profiles.
Column {
    id: root
    spacing: 4
    Component.onCompleted: if (!Rgb.scanned) Rgb.scan()
    property color picked: Theme.accent
    readonly property var swatches: ["#ff0000", "#ff8c00", "#ffd700", "#00c853", "#00b7c3", "#0078d4", "#6b69d6", "#8764b8", "#e3008c", "#ffffff"]

    SettingRow {
        width: parent.width
        glyph: ""; title: "Use Dynamic Lighting on my devices"
        subtitle: !Rgb.scanned ? "Looking for devices…" : !Rgb.available ? "OpenRGB isn't installed, or found no lights" : Rgb.devices.length + " device(s)"
        Btn { text: "Look again"; enabled: !Rgb.busy; onClicked: Rgb.scan() }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Match my Windows accent color"; subtitle: "The lights follow the theme"
        Toggle { enabled: Rgb.available; checked: Rgb.followWallpaper; onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper) }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Colour"; subtitle: "Set every light to one colour"
        Row {
            spacing: 6
            Repeater {
                model: root.swatches
                Rectangle {
                    required property string modelData
                    width: 28; height: 28; radius: 14
                    color: modelData
                    border.width: Qt.color(modelData).toString() === root.picked.toString() ? 3 : 1
                    border.color: Qt.color(modelData).toString() === root.picked.toString() ? Theme.text : Theme.controlStroke
                    MouseArea { anchors.fill: parent; onClicked: root.picked = modelData }
                }
            }
            Btn { kind: "accent"; text: "Apply"; enabled: Rgb.available && !Rgb.busy; onClicked: Rgb.setAll(root.picked) }
            Btn { text: "Off"; enabled: Rgb.available && !Rgb.busy; onClicked: Rgb.setAll("#000000") }
        }
    }
    Header { text: "Devices"; visible: Rgb.devices.length > 0 }
    Repeater {
        model: Rgb.devices
        SettingRow {
            id: dev
            required property var modelData
            property string mode: modelData.mode || Rgb.colorMode(modelData)
            width: root.width
            glyph: ""; title: modelData.name; subtitle: modelData.type
            Row {
                spacing: 6
                Combo { width: 160; model: dev.modelData.modes ?? []; currentIndex: (dev.modelData.modes ?? []).indexOf(dev.mode); onChosen: i => dev.mode = dev.modelData.modes[i] }
                Btn { text: "Set"; enabled: !Rgb.busy; onClicked: Rgb.setDevice(dev.modelData, dev.mode, root.picked) }
            }
        }
    }
    Header { text: "Profiles"; visible: Rgb.profiles.length > 0 }
    Repeater {
        model: Rgb.profiles
        SettingRow {
            required property var modelData
            width: root.width
            glyph: ""; title: modelData
            Btn { text: "Load"; enabled: !Rgb.busy; onClicked: Rgb.loadProfile(modelData) }
        }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Save the lights as a profile"
        Row {
            spacing: 6
            Field { id: prof; width: 200; placeholder: "Profile name" }
            Btn { text: "Save"; enabled: !Rgb.busy && prof.text.trim() !== ""; onClicked: { Rgb.saveProfile(prof.text.trim()); prof.text = ""; } }
        }
    }
    Txt { visible: Rgb.error !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: Rgb.error }
}
