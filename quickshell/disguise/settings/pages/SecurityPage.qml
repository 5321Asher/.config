import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Privacy & security → Windows Security's "Virus & threat protection", for real: packages with
// known vulnerabilities (arch-audit), by risk, and whether an update fixes them.
Column {
    id: root
    spacing: 4
    Card {
        width: parent.width
        height: 110
        Glyph {
            x: 24; anchors.verticalCenter: parent.verticalCenter
            g: Updates.high > 0 ? "" : ""
            size: 44
            color: Updates.high > 0 ? Theme.danger : Updates.count > 0 ? Theme.warn : Theme.green
        }
        Column {
            x: 92
            anchors.verticalCenter: parent.verticalCenter
            Txt {
                size: Theme.subtitle; strong: true
                text: !Updates.auditAvailable ? "Protection isn't set up" : Updates.high > 0 ? "Action recommended" : Updates.count > 0 ? "Some packages need attention" : "No actions needed"
            }
            Txt {
                level: 2
                text: !Updates.auditAvailable ? "Install arch-audit to check your packages for known vulnerabilities"
                    : Updates.count + " vulnerable packages · " + Updates.high + " high risk · " + Updates.fixable + " fixed by updating"
                    + (Updates.auditAt ? " · checked " + Updates.ago() : "")
            }
        }
        Btn { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
              text: Updates.auditing ? "Scanning…" : "Quick scan"; enabled: !Updates.auditing; onClicked: Updates.sweep() }
    }
    SettingRow {
        visible: Updates.fixable > 0
        width: parent.width
        glyph: ""; title: Updates.fixable + " can be fixed by updating"
        Btn { kind: "accent"; text: "Go to Windows Update"; onClicked: SettingsApp.open("update") }
    }
    Header { text: "Current threats"; visible: Updates.count > 0 }
    Repeater {
        model: Updates.vulns
        SettingRow {
            required property var modelData
            readonly property bool high: modelData.severity === "Critical" || modelData.severity === "High"
            width: root.width
            glyph: ""
            title: modelData.name + " · " + modelData.severity
            subtitle: modelData.type + " · " + modelData.cves + " CVE" + (modelData.cves === 1 ? "" : "s")
            Txt { height: 32; text: modelData.fix ? "Update available" : "No fix yet"; color: modelData.fix ? Theme.green : Theme.text2 }
        }
    }
}
