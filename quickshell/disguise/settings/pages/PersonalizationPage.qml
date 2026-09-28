import QtQuick
import "../../theme"
import "../../widgets"
import ".."

// Personalization: a preview of the desktop, the themes to pick from, then its pages.
Column {
    id: root
    spacing: 4
    Component.onCompleted: Look.refresh()
    Card {
        width: parent.width
        height: 200
        Rectangle {
            x: 20; anchors.verticalCenter: parent.verticalCenter
            width: 260; height: 150; radius: Theme.radiusLarge
            color: Theme.desktop
            clip: true
            border.width: 4
            border.color: Theme.dark ? "#1a1a1a" : "#2b2b2b"
            Image {
                anchors.fill: parent; anchors.margins: 4
                source: Look.wallNow && !Look.isVideo(Look.wallNow) ? "file://" + Look.wallNow : ""
                fillMode: Image.PreserveAspectCrop; sourceSize.width: 520; asynchronous: true
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 4; x: 4; width: parent.width - 8; height: 12; color: Qt.alpha(Theme.taskbar, 0.85) }
        }
        Column {
            x: 300; y: 24
            width: parent.width - 320
            spacing: 8
            Txt { text: "Select a theme to apply"; strong: true }
            Flow {
                width: parent.width
                spacing: 8
                Repeater { model: Look.themes; ThemeChip { required property var modelData; theme: modelData; scale: 0.8; width: 106; height: 88 } }
            }
        }
    }
    SettingRow { width: parent.width; glyph: ""; title: "Background"; subtitle: "Background image, slideshow"; clickable: true; onClicked: SettingsApp.go("background") }
    SettingRow { width: parent.width; glyph: ""; title: "Themes"; subtitle: "Colours, and the whole desktop (setups)"; clickable: true; onClicked: SettingsApp.go("themes") }
    SettingRow { width: parent.width; glyph: ""; title: "Dynamic Lighting"; subtitle: "Connected RGB devices (OpenRGB)"; clickable: true; onClicked: SettingsApp.go("lighting") }
}
