import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Notifications: Do not disturb, and the notifications you've had (clear them one by one or all).
Column {
    id: root
    spacing: 4
    SettingRow {
        width: parent.width
        glyph: ""; title: "Notifications"; subtitle: "Get notifications from apps and other senders"
        Toggle { checked: !Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
    }
    SettingRow {
        width: parent.width
        glyph: ""; title: "Do not disturb"; subtitle: "Notifications go straight to the notification center; urgent ones still show"
        Toggle { checked: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
    }
    Header { text: "Notification history" }
    Row {
        spacing: 8
        Btn { text: "Clear all"; enabled: Notifs.history.length > 0; onClicked: Notifs.clearAll() }
        Txt { height: Theme.controlHeight; text: Notifs.history.length + " notification" + (Notifs.history.length === 1 ? "" : "s"); level: 2 }
    }
    Repeater {
        model: Notifs.history
        SettingRow {
            required property var modelData
            width: root.width
            glyph: ""
            title: (modelData.appName ? modelData.appName + ": " : "") + (modelData.summary ?? "")
            subtitle: (modelData.body ?? "").replace(/<[^>]+>/g, "").slice(0, 200)
            Btn { kind: "subtle"; glyph: ""; glyphSize: 12; width: 32; onClicked: modelData.dismiss() }
        }
    }
}
