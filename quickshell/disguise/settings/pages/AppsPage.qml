import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../flyouts"
import ".."

// Installed apps: search, then every app with its menu (open, pin to Start / taskbar).
Column {
    id: root
    spacing: 4
    property string q: ""
    readonly property var list: q ? Apps.find(q) : Apps.all

    Row {
        spacing: 12
        Field { width: 320; placeholder: "Search apps"; glyph: ""; onTextChanged: root.q = text }
        Txt { height: Theme.controlHeight; text: root.list.length + " apps found"; level: 2 }
    }
    Item { width: 1; height: 4 }
    Repeater {
        model: root.list
        SettingRow {
            required property var modelData
            width: root.width
            title: modelData.name
            subtitle: modelData.genericName || modelData.comment || modelData.id
            Row {
                spacing: 4
                Btn { text: "Open"; onClicked: Apps.launch(modelData) }
                Btn {
                    id: pinBtn
                    kind: "subtle"; glyph: Apps.isPinned("start", modelData) ? "" : ""; width: 36
                    onClicked: Apps.togglePin("start", modelData)
                    Tip { target: pinBtn; hovered: pinBtn.hovered; text: Apps.isPinned("start", modelData) ? "Unpin from Start" : "Pin to Start" }
                }
            }
            icon: modelData.icon || "application-x-executable"
        }
    }
}
