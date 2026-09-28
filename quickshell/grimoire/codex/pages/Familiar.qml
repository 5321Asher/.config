import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// XI. Familiar: your Claude Code, the spirit at your elbow: who it serves, its limits as filling
// meters (red when nearly spent) with when they renew, and today's work.
Column {
    id: root

    spacing: 22
    Component.onCompleted: ClaudeStatus.refreshIfStale()
    readonly property var d: ClaudeStatus.data

    Row {
        spacing: 8
        Btn { text: "summon claude code"; primary: true; onClicked: { CodexState.open = false; ClaudeStatus.launch(); } }
        Btn { text: ClaudeStatus.loading ? "asking…" : "ask again"; enabled: !ClaudeStatus.loading; onClicked: ClaudeStatus.refresh() }
    }
    Body { visible: !root.d && !ClaudeStatus.loading; text: "The familiar hasn't spoken yet."; italic: true; color: Theme.inkDim }
    Body { visible: (root.d?.error ?? "") !== ""; width: parent.width; wrapMode: Text.Wrap; text: root.d?.error ?? ""; color: Theme.danger; italic: true }

    Section {
        visible: !!root.d?.account
        title: "whom it serves"
        trailing: "version " + (root.d?.version ?? "")
        KV { key: "name"; value: root.d?.account?.name ?? "" }
        KV { key: "account"; value: root.d?.account?.email ?? "" }
        KV { key: "plan"; value: root.d?.account?.plan ?? "" }
        KV { key: root.d?.model?.configured ? "model" : "last model"; value: ClaudeStatus.prettyModel(root.d?.model?.configured || root.d?.model?.lastUsed || "") }
    }

    Section {
        visible: (root.d?.limits ?? []).length > 0
        title: "its limits"
        Repeater {
            model: root.d?.limits ?? []
            Column {
                id: lim
                required property var modelData
                readonly property real f: (modelData.percent ?? 0) / 100
                readonly property bool hot: modelData.severity !== "normal" || f >= 0.9
                width: parent.width
                spacing: 4
                KV { key: lim.modelData.label + (lim.modelData.active ? " · now" : ""); value: Math.round(lim.f * 100) + "% spent"; color: lim.hot ? Theme.rubric : Theme.ink }
                Meter { width: parent.width; height: 10; color: Theme.arcane; hot: lim.hot ? -1 : 2; value: lim.f }
                Body { visible: !!lim.modelData.resetsAt; text: "renews " + ClaudeStatus.resetsIn(lim.modelData.resetsAt); italic: true; color: Theme.inkDim; font.pixelSize: 13 }
            }
        }
    }

    Section {
        visible: !!root.d?.today
        title: "today's work"
        KV { key: "sessions"; value: String(root.d?.today?.sessions ?? 0) }
        KV { key: "messages"; value: String(root.d?.today?.messages ?? 0) }
        KV { key: "tokens in"; value: ClaudeStatus.tokens(root.d?.today?.tokensIn ?? 0) }
        KV { key: "tokens out"; value: ClaudeStatus.tokens(root.d?.today?.tokensOut ?? 0) }
    }
}
