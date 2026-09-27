import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme"
import "../../services"
import ".."

// Claude: the Claude Code account, the model last used, usage limits as dials (when they reset),
// extra usage and today's activity. Launch opens Claude Code in a terminal.
// Data: services/ClaudeStatus.qml (scripts/claude-info.py).
Column {
    id: root

    spacing: 22

    Component.onCompleted: ClaudeStatus.refreshIfStale()
    readonly property var d: ClaudeStatus.data

    Row {
        spacing: 8
        Link { text: "launch claude code"; glyph: "\u{f06a9}"; primary: true; onClicked: { DeckState.open = false; ClaudeStatus.launch(); } }
        Link { text: ClaudeStatus.loading ? "refreshing…" : "refresh"; enabled: !ClaudeStatus.loading; onClicked: ClaudeStatus.refresh() }
    }

    Text {
        visible: !root.d && !ClaudeStatus.loading
        text: "no data yet"
        color: Theme.dim
        font.family: Theme.fontData
        font.pixelSize: Theme.dataSize
    }
    Text {
        visible: (root.d?.error ?? "") !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: root.d?.error ?? ""
        color: Theme.signal
        font.family: Theme.fontData
        font.pixelSize: Theme.dataSizeSmall
    }

    // ---------------------------------------------------------------- account
    Section {
        visible: !!root.d?.account
        title: "account"
        trailing: "v" + (root.d?.version ?? "")
        ListRow {
            clickable: false
            glyph: "\u{f0004}"
            title: root.d?.account?.name ?? ""
            subtitle: (root.d?.account?.email ?? "")
            trailing: (root.d?.account?.plan ?? "").toLowerCase()
            trailingColor: Theme.brassBright
        }
        ListRow {
            clickable: false
            glyph: "\u{f06a9}"
            title: ClaudeStatus.prettyModel(root.d?.model?.configured || root.d?.model?.lastUsed || "")
            subtitle: root.d?.model?.configured ? "configured model" : "last used"
        }
    }

    // ---------------------------------------------------------------- limits
    Section {
        visible: (root.d?.limits ?? []).length > 0
        title: "limits"
        Flow {
            width: parent.width
            spacing: 18
            Repeater {
                model: root.d?.limits ?? []
                Column {
                    id: lim
                    required property var modelData
                    width: 180
                    spacing: 4
                    readonly property real f: (modelData.percent ?? 0) / 100
                    readonly property bool hot: modelData.severity !== "normal" || f >= 0.9
                    Item {
                        width: 180
                        height: 110
                        Canvas {
                            id: lc
                            anchors.fill: parent
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const cx = width / 2, cy = 80, r = 64;
                                const a0 = Math.PI, a1 = 2 * Math.PI;
                                // a half dial, like a pressure gauge
                                ctx.strokeStyle = Theme.alpha(Theme.brass, 0.9);
                                ctx.lineWidth = 1.2;
                                ctx.beginPath(); ctx.arc(cx, cy, r + 4, a0, a1); ctx.stroke();
                                for (let i = 0; i <= 20; i++) {
                                    const a = a0 + i / 20 * Math.PI, big = i % 5 === 0;
                                    ctx.strokeStyle = i >= 18 ? Theme.alpha(Theme.signal, 0.9) : Theme.alpha(Theme.brass, big ? 0.9 : 0.4);
                                    ctx.beginPath();
                                    ctx.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
                                    ctx.lineTo(cx + (r - (big ? 9 : 5)) * Math.cos(a), cy + (r - (big ? 9 : 5)) * Math.sin(a));
                                    ctx.stroke();
                                }
                                ctx.strokeStyle = Theme.alpha(lim.hot ? Theme.signal : Theme.phosphor, 0.65);
                                ctx.lineWidth = 4;
                                ctx.beginPath(); ctx.arc(cx, cy, r - 16, a0, a0 + Math.PI * Math.min(1, lim.f)); ctx.stroke();
                                const a = a0 + Math.PI * Math.min(1, lim.f);
                                ctx.strokeStyle = lim.hot ? Theme.signal : Theme.brassBright;
                                ctx.lineWidth = 2;
                                ctx.beginPath();
                                ctx.moveTo(cx, cy);
                                ctx.lineTo(cx + (r - 6) * Math.cos(a), cy + (r - 6) * Math.sin(a));
                                ctx.stroke();
                                ctx.fillStyle = Theme.brass;
                                ctx.beginPath(); ctx.arc(cx, cy, 4, 0, 2 * Math.PI); ctx.fill();
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 86
                            text: Math.round(lim.f * 100) + "%"
                            color: lim.hot ? Theme.signal : Theme.starlight
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize + 3
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowColor: Theme.brass; shadowBlur: 0.4; shadowOpacity: 0.4
                            shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12
                        }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: (lim.modelData.label ?? "").toLowerCase()
                        color: lim.modelData.active ? Theme.brassBright : Theme.brass
                        font.family: Theme.fontLabel
                        font.pixelSize: Theme.labelSize
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: Theme.labelSpacing
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: lim.modelData.resetsAt ? "resets " + ClaudeStatus.resetsIn(lim.modelData.resetsAt) : ""
                        color: Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- activity
    Section {
        visible: !!root.d?.today
        title: "today"
        Grid {
            width: parent.width
            columns: 2
            columnSpacing: 12
            rowSpacing: 10
            Repeater {
                model: [
                    ["sessions", root.d?.today?.sessions ?? 0],
                    ["messages", root.d?.today?.messages ?? 0],
                    ["tokens in", ClaudeStatus.tokens(root.d?.today?.tokensIn ?? 0)],
                    ["tokens out", ClaudeStatus.tokens(root.d?.today?.tokensOut ?? 0)],
                ]
                Rectangle {
                    required property var modelData
                    width: (parent.width - 12) / 2
                    height: 54
                    radius: 5
                    color: Theme.alpha(Theme.bgDark, 0.7)
                    border.width: 1
                    border.color: Theme.alpha(Theme.border, 0.9)
                    Column {
                        anchors.centerIn: parent
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(modelData[1])
                            color: Theme.starlight
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize + 5
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData[0]
                            color: Theme.brass
                            font.family: Theme.fontLabel
                            font.pixelSize: Theme.labelSize - 1
                            font.capitalization: Font.SmallCaps
                            font.letterSpacing: Theme.labelSpacing
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
        ListRow {
            visible: (root.d?.extra?.limit ?? 0) > 0
            clickable: false
            glyph: "\u{f0114}"
            title: "extra usage"
            subtitle: (root.d?.extra?.used ?? 0).toFixed(2) + " of " + (root.d?.extra?.limit ?? 0) + " " + (root.d?.extra?.currency ?? "")
        }
    }
}
