import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Accounts: you, and your Claude account (Claude Code: plan, model, today's numbers, and the usage
// limits with when they reset).
Column {
    id: root
    spacing: 4
    Component.onCompleted: ClaudeStatus.refreshIfStale()
    readonly property var d: ClaudeStatus.data
    SysBits { id: sys }

    Card {
        width: parent.width
        height: 120
        Avatar { x: 24; anchors.verticalCenter: parent.verticalCenter; size: 80 }
        Column {
            x: 124
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: sys.fullName || sys.user; size: Theme.subtitle; strong: true }
            Txt { text: sys.user + "@" + sys.host; level: 2 }
            Txt { text: "Administrator · Local account"; level: 2; size: Theme.caption }
        }
    }
    Header { text: "Claude" }
    SettingRow {
        width: parent.width
        glyph: ""
        title: root.d?.account?.name ?? (ClaudeStatus.loading ? "Checking…" : "No Claude Code account found")
        subtitle: root.d?.account ? (root.d.account.email ?? "") + " · " + (root.d.account.plan ?? "").replace(/^./, c => c.toUpperCase()) + " plan" : (root.d?.error ?? "")
        Row {
            spacing: 6
            Btn { kind: "subtle"; glyph: ""; width: 36; enabled: !ClaudeStatus.loading; onClicked: ClaudeStatus.refresh() }
            Btn { kind: "accent"; text: "Start Claude Code"; onClicked: ClaudeStatus.launch() }
        }
    }
    SettingRow {
        visible: !!root.d
        width: parent.width
        glyph: ""; title: "Claude Code " + (root.d?.version ?? "")
        subtitle: (root.d?.model?.configured ? "Model: " : "Last used: ") + ClaudeStatus.prettyModel(root.d?.model?.configured || root.d?.model?.lastUsed || "")
    }
    SettingRow {
        visible: !!root.d?.today
        width: parent.width
        glyph: ""; title: "Today"
        subtitle: (root.d?.today?.sessions ?? 0) + " sessions · " + (root.d?.today?.messages ?? 0) + " messages · "
            + ClaudeStatus.tokens(root.d?.today?.tokensIn ?? 0) + " in / " + ClaudeStatus.tokens(root.d?.today?.tokensOut ?? 0) + " out"
    }
    Repeater {
        model: root.d?.limits ?? []
        Card {
            id: lim
            required property var modelData
            readonly property real f: (modelData.percent ?? 0) / 100
            readonly property bool hot: modelData.severity !== "normal" || f >= 0.9
            width: root.width
            height: 84
            Txt { x: 20; y: 14; text: lim.modelData.label + (lim.modelData.active ? " (now)" : ""); strong: true }
            Txt { anchors.right: parent.right; anchors.rightMargin: 20; y: 14; text: Math.round(lim.f * 100) + "% used"; color: lim.hot ? Theme.danger : Theme.text2 }
            Progress { x: 20; y: 46; width: parent.width - 40; value: lim.f; color: lim.hot ? Theme.danger : Theme.accent }
            Txt { x: 20; y: 56; visible: !!lim.modelData.resetsAt; text: "Resets " + ClaudeStatus.resetsIn(lim.modelData.resetsAt ?? ""); size: Theme.caption; level: 2 }
        }
    }
}
