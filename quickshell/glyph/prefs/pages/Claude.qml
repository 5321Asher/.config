import QtQuick
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// CLAUDE: your Claude Code account, the usage limits as rings of dots (red when nearly spent) with
// when they reset, and today's numbers in Doto.
Column {
    id: root

    spacing: 40
    Component.onCompleted: ClaudeStatus.refreshIfStale()
    readonly property var d: ClaudeStatus.data

    Row {
        spacing: 8
        Btn { text: "launch claude code"; primary: true; onClicked: { PrefsState.open = false; ClaudeStatus.launch(); } }
        Btn { text: ClaudeStatus.loading ? "syncing…" : "refresh"; enabled: !ClaudeStatus.loading; onClicked: ClaudeStatus.refresh() }
    }
    Lb { visible: !root.d && !ClaudeStatus.loading; text: "no claude code data" }
    Lb { visible: (root.d?.error ?? "") !== ""; width: parent.width; wrapMode: Text.Wrap; text: root.d?.error ?? ""; color: Theme.red }

    Section {
        visible: !!root.d?.account
        title: "account"
        
        trailing: "v" + (root.d?.version ?? "")
        KV { key: "name"; value: root.d?.account?.name ?? "" }
        KV { key: "account"; value: root.d?.account?.email ?? "" }
        KV { key: "plan"; value: (root.d?.account?.plan ?? "").toUpperCase(); color: Theme.fg }
        KV { key: root.d?.model?.configured ? "model" : "last model"; value: ClaudeStatus.prettyModel(root.d?.model?.configured || root.d?.model?.lastUsed || "") }
    }

    Section {
        visible: (root.d?.limits ?? []).length > 0
        title: "limits"
        
        Flow {
            width: parent.width
            spacing: 34
            Repeater {
                model: root.d?.limits ?? []
                Item {
                    id: lim
                    required property var modelData
                    readonly property real f: (modelData.percent ?? 0) / 100
                    readonly property bool hot: modelData.severity !== "normal" || f >= 0.9
                    width: 190
                    height: 250
                    Ring { width: 190; height: 190; n: 44; dot: 6; f: lim.f; on: lim.hot ? Theme.red : Theme.fg }
                    Num { x: (190 - width) / 2; y: (190 - height) / 2; text: Math.round(lim.f * 100); font.pixelSize: 64 }
                    Column {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                        spacing: 6
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: lim.modelData.label + (lim.modelData.active ? " · now" : ""); color: Theme.fg; px: 10 }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; visible: !!lim.modelData.resetsAt; text: "resets " + ClaudeStatus.resetsIn(lim.modelData.resetsAt); px: 9 }
                    }
                }
            }
        }
    }

    Section {
        visible: !!root.d?.today
        title: "today"
        
        Row {
            spacing: 50
            Repeater {
                model: [["sessions", String(root.d?.today?.sessions ?? 0)], ["messages", String(root.d?.today?.messages ?? 0)],
                        ["tokens in", ClaudeStatus.tokens(root.d?.today?.tokensIn ?? 0)], ["tokens out", ClaudeStatus.tokens(root.d?.today?.tokensOut ?? 0)]]
                Column {
                    required property var modelData
                    Num { text: modelData[1]; font.pixelSize: 56 }
                    Lb { topPadding: 10; text: modelData[0] }
                }
            }
        }
    }
}
