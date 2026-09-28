import QtQuick
import "../../theme"
import "../../widgets"
import ".."

// Themes: this setup's colour themes, then the setups (the whole desktop: this one is Disguise).
Column {
    id: root
    spacing: 4
    Component.onCompleted: Look.refresh()
    Header { text: "Current theme: " + (Look.themes.find(t => t.current)?.name ?? ""); topPadding: 0 }
    Card {
        width: parent.width
        height: flow.height + 32
        Flow {
            id: flow
            x: 16; y: 16
            width: parent.width - 32
            spacing: 12
            Repeater { model: Look.themes; ThemeChip { required property var modelData; theme: modelData } }
        }
    }
    Header { text: "Desktop setups" }
    Repeater {
        model: Look.setups
        SettingRow {
            required property var modelData
            width: root.width
            glyph: modelData.current ? "" : ""
            title: modelData.name
            subtitle: modelData.about + (modelData.current ? " · in use" : "")
            Btn { visible: !modelData.current; text: "Switch"; onClicked: Look.setSetup(modelData.id) }
        }
    }
}
