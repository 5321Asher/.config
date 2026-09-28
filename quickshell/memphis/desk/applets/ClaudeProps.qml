import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Claude Properties: your Claude Code account, the usage limits as 98 progress bars (red when
// nearly spent) with when they reset, and today's numbers. Data: services/ClaudeStatus.qml.
Props {
    id: root

    title: "Claude Properties"
    icon: "help-about"
    tabs: ["General", "Usage"]

    Component.onCompleted: ClaudeStatus.refreshIfStale()
    readonly property var d: ClaudeStatus.data

    // ---------------------------------------------------------------- General
    Column {
        spacing: 8
        Txt { visible: !root.d; text: ClaudeStatus.loading ? "Please wait…" : "No Claude Code information." }
        Txt { visible: (root.d?.error ?? "") !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.danger; text: root.d?.error ?? "" }
        Row {
            visible: !!root.d?.account
            spacing: 16
            Icon { name: "avatar-default"; fallback: "user-info"; size: 48 }
            Column {
                spacing: 2
                Txt { text: root.d?.account?.name ?? ""; bold: true }
                Txt { text: root.d?.account?.email ?? "" }
                Txt { text: "Plan: " + (root.d?.account?.plan ?? "").replace(/^./, c => c.toUpperCase()) }
            }
        }
        Group {
            visible: !!root.d
            title: "Claude Code"
            width: parent.width
            Txt { text: "Version: " + (root.d?.version ?? "") }
            Txt {
                text: (root.d?.model?.configured ? "Model: " : "Last used: ")
                    + ClaudeStatus.prettyModel(root.d?.model?.configured || root.d?.model?.lastUsed || "")
            }
        }
        Group {
            visible: !!root.d?.today
            title: "Today"
            width: parent.width
            Txt { text: "Sessions: " + (root.d?.today?.sessions ?? 0) + "      Messages: " + (root.d?.today?.messages ?? 0) }
            Txt { text: "Tokens in: " + ClaudeStatus.tokens(root.d?.today?.tokensIn ?? 0) + "      Tokens out: " + ClaudeStatus.tokens(root.d?.today?.tokensOut ?? 0) }
        }
        Row {
            spacing: 6
            Btn { text: "Start Claude Code"; isDefault: true; onClicked: { root.closeRequested(); ClaudeStatus.launch(); } }
            Btn { text: ClaudeStatus.loading ? "Refreshing…" : "Refresh"; enabled: !ClaudeStatus.loading; onClicked: ClaudeStatus.refresh() }
        }
    }

    // ---------------------------------------------------------------- Usage
    Column {
        spacing: 10
        Txt { visible: (root.d?.limits ?? []).length === 0; text: "No usage limits to show." }
        Repeater {
            model: root.d?.limits ?? []
            Group {
                id: lim
                required property var modelData
                readonly property real f: (modelData.percent ?? 0) / 100
                readonly property bool hot: modelData.severity !== "normal" || f >= 0.9
                title: modelData.label + (modelData.active ? " (now)" : "")
                width: parent.width
                Progress { width: parent.width; height: 24; value: lim.f; color: lim.hot ? Theme.danger : Theme.select }
                Txt {
                    text: Math.round(lim.f * 100) + "% used" + (lim.modelData.resetsAt ? ", resets " + ClaudeStatus.resetsIn(lim.modelData.resetsAt) : "")
                    color: lim.hot ? Theme.danger : Theme.text
                }
            }
        }
    }
}
