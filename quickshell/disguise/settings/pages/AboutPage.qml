import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// About: Device specifications and Windows specifications, as Windows lays them out (with Copy).
Column {
    id: root
    spacing: 4
    SysBits { id: sys }
    Component.onCompleted: SysStats.active = true
    Component.onDestruction: SysStats.active = false
    readonly property var d: SysStats.data
    readonly property var device: [
        ["Device name", sys.host], ["Model", sys.model], ["Processor", d?.cpu?.name ?? "…"], ["Graphics", d?.gpu?.name ?? "—"],
        ["Installed RAM", d ? SysStats.bytes(d.mem.total, 1) : "…"], ["User", (sys.fullName ? sys.fullName + " (" + sys.user + ")" : sys.user)],
    ]
    readonly property var windows: [
        ["Edition", sys.os], ["Version", "Linux " + sys.kernel], ["Desktop", "Hyprland, dressed as Windows 11 (Disguise)"],
        ["Installed on", sys.installed], ["Up for", sys.uptime()],
    ]
    function text(list) { return list.map(r => r[0] + "\t" + r[1]).join("\n"); }

    Spec { title: "Device specifications"; glyph: ""; rows: root.device }
    Spec { title: "Windows specifications"; glyph: ""; rows: root.windows }
    Header { text: "Related" }
    SettingRow { width: parent.width; glyph: ""; title: "Task Manager"; subtitle: "What's using the processor, memory and graphics"; clickable: true; onClicked: SettingsApp.go("performance") }
    SettingRow { width: parent.width; glyph: ""; title: "System information"; subtitle: "fastfetch, in the terminal"; clickable: true; chevron: ""
                 onClicked: Quickshell.execDetached(["kitty", "--hold", "fastfetch"]) }

    component Spec: Card {
        id: spec
        property string title
        property string glyph
        property var rows: []
        width: root.width
        height: 64 + rows.length * 30 + 12
        Glyph { x: 18; y: 22; g: spec.glyph; size: 20 }
        Txt { x: 56; y: 20; text: spec.title; strong: true }
        Btn { anchors.right: parent.right; anchors.rightMargin: 16; y: 16; text: "Copy"; onClicked: Quickshell.execDetached(["wl-copy", root.text(spec.rows)]) }
        Column {
            x: 56; y: 60
            width: parent.width - 72
            Repeater {
                model: spec.rows
                Row {
                    required property var modelData
                    height: 30
                    Txt { width: 180; height: 30; text: modelData[0]; level: 2 }
                    Txt { width: spec.width - 260; height: 30; text: modelData[1] ?? "" }
                }
            }
        }
    }
}
