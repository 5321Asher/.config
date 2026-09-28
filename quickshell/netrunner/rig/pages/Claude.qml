import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// 11 CLAUDE 助手: your Claude Code account, the usage limits as block meters (red when nearly
// spent) with when they reset, and today's numbers.
Column {
    id: root

    spacing: 22
    Component.onCompleted: ClaudeStatus.refreshIfStale()
    readonly property var d: ClaudeStatus.data

    Row {
        spacing: 8
        Btn { text: "launch claude code"; primary: true; onClicked: { RigState.open = false; ClaudeStatus.launch(); } }
        Btn { text: ClaudeStatus.loading ? "syncing…" : "refresh"; enabled: !ClaudeStatus.loading; onClicked: ClaudeStatus.refresh() }
    }
    Label { visible: !root.d && !ClaudeStatus.loading; text: "// no claude code data" }
    Label { visible: (root.d?.error ?? "") !== ""; width: parent.width; wrapMode: Text.Wrap; text: root.d?.error ?? ""; color: Theme.red }

    Section {
        visible: !!root.d?.account
        title: "operator"
        jp: "操作者"
        trailing: "v" + (root.d?.version ?? "")
        KV { key: "name"; value: root.d?.account?.name ?? "" }
        KV { key: "account"; value: root.d?.account?.email ?? "" }
        KV { key: "plan"; value: (root.d?.account?.plan ?? "").toUpperCase(); color: Theme.cyan }
        KV { key: root.d?.model?.configured ? "model" : "last model"; value: ClaudeStatus.prettyModel(root.d?.model?.configured || root.d?.model?.lastUsed || "") }
    }

    Section {
        visible: (root.d?.limits ?? []).length > 0
        title: "limits"
        jp: "制限"
        Repeater {
            model: root.d?.limits ?? []
            Column {
                id: lim
                required property var modelData
                readonly property real f: (modelData.percent ?? 0) / 100
                readonly property bool hot: modelData.severity !== "normal" || f >= 0.9
                width: parent.width
                spacing: 4
                KV { key: lim.modelData.label + (lim.modelData.active ? "  //  now" : ""); value: Math.round(lim.f * 100) + "%"; color: lim.hot ? Theme.red : Theme.cyan }
                Blocks { count: 40; blockWidth: (root.width - 39 * 2) / 40; blockHeight: 8; value: lim.f; color: lim.hot ? Theme.red : Theme.cyan }
                Label { visible: !!lim.modelData.resetsAt; text: "resets " + ClaudeStatus.resetsIn(lim.modelData.resetsAt) }
            }
        }
    }

    Section {
        visible: !!root.d?.today
        title: "today"
        jp: "本日"
        KV { key: "sessions"; value: String(root.d?.today?.sessions ?? 0) }
        KV { key: "messages"; value: String(root.d?.today?.messages ?? 0) }
        KV { key: "tokens in"; value: ClaudeStatus.tokens(root.d?.today?.tokensIn ?? 0) }
        KV { key: "tokens out"; value: ClaudeStatus.tokens(root.d?.today?.tokensOut ?? 0) }
    }
}
