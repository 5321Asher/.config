import QtQuick
import QtQuick.Layouts

// Claude Code status card: account, model, usage limits, today's activity
ColumnLayout {
    id: root

    readonly property var d: ClaudeStatus.data

    signal launchRequested

    width: 320
    spacing: 14

    // Header
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            implicitWidth: 40
            implicitHeight: 40
            radius: 0
            color: Theme.hover

            ClaudeMark {
                anchors.centerIn: parent
                width: 20
                height: 20
                color: Theme.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: "Claude Code"
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
                color: Theme.fg
            }

            Text {
                Layout.fillWidth: true
                text: [root.d?.account?.name, root.d?.version ? "v" + root.d.version : ""].filter(s => s).join("  ·  ")
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        // Plan badge
        Rectangle {
            visible: !!root.d?.account?.plan
            implicitWidth: planText.implicitWidth + 16
            implicitHeight: 22
            radius: 0
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)

            Text {
                id: planText
                anchors.centerIn: parent
                text: (root.d?.account?.plan ?? "").toUpperCase()
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
                color: Theme.accent
            }
        }
    }

    // Model
    InfoRow {
        label: "Model"
        value: root.d?.model?.configured
            ? ClaudeStatus.prettyModel(root.d.model.configured)
            : "Default" + (root.d?.model?.lastUsed ? " (" + ClaudeStatus.prettyModel(root.d.model.lastUsed) + ")" : "")
    }

    InfoRow {
        visible: !!root.d?.account?.email
        label: "Account"
        value: root.d?.account?.email ?? ""
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.hover
    }

    // Usage limits
    Text {
        text: "USAGE LIMITS"
        font.family: Theme.font
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 2
        color: Theme.dim
    }

    Text {
        Layout.fillWidth: true
        visible: !!root.d?.error
        text: root.d?.error ?? ""
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: 11
        color: Theme.warn
    }

    Text {
        visible: !root.d && ClaudeStatus.loading
        text: "Loading…"
        font.family: Theme.font
        font.pixelSize: 11
        color: Theme.dim
    }

    Repeater {
        model: root.d?.limits ?? []

        LimitBar {
            required property var modelData
            label: modelData.label
            percent: modelData.percent
            tint: modelData.severity === "critical" || modelData.percent >= 90 ? Theme.danger
                : modelData.severity === "warning" || modelData.percent >= 75 ? Theme.warn : Theme.accent
            detail: modelData.resetsAt ? "Resets " + ClaudeStatus.resetsIn(modelData.resetsAt) : ""
        }
    }

    LimitBar {
        visible: !!root.d?.extra
        label: "Extra usage"
        percent: root.d?.extra?.limit ? 100 * root.d.extra.used / root.d.extra.limit : 0
        tint: Theme.purple
        detail: root.d?.extra
            ? "$" + root.d.extra.used.toFixed(2) + " of $" + root.d.extra.limit.toFixed(2) + " " + root.d.extra.currency + " this month"
            : ""
        showPercent: false
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.hover
    }

    // Today
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Stat { value: root.d?.today?.sessions ?? 0; label: "sessions today" }
        Stat { value: root.d?.today?.messages ?? 0; label: "replies" }
        Stat { value: ClaudeStatus.tokens(root.d?.today?.tokensOut ?? 0); label: "tokens out" }
    }

    // Actions
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        IconButton {
            icon: String.fromCodePoint(0xF0450)
            label: ClaudeStatus.loading ? "Refreshing…" : "Refresh"
            spinning: ClaudeStatus.loading
            onClicked: ClaudeStatus.refresh()
        }

        Item { Layout.fillWidth: true }

        IconButton {
            primary: true
            label: "Open Claude Code"
            onClicked: root.launchRequested()
        }
    }

    component InfoRow: RowLayout {
        property string label
        property string value

        Layout.fillWidth: true
        spacing: 12

        Text {
            text: parent.label
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.dim
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: parent.value
            elide: Text.ElideMiddle
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
            color: Theme.fg
        }
    }

    component LimitBar: ColumnLayout {
        id: lb

        property string label
        property real percent
        property color tint
        property string detail
        property bool showPercent: true

        Layout.fillWidth: true
        spacing: 5

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: lb.label
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
                color: Theme.fg
            }

            Text {
                visible: lb.showPercent
                text: Math.round(lb.percent) + "%"
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
                color: lb.tint
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 0
            color: Theme.hover

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(100, lb.percent) / 100)
                height: parent.height
                radius: 0
                color: lb.tint

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            visible: lb.detail !== ""
            text: lb.detail
            font.family: Theme.font
            font.pixelSize: 10
            color: Theme.dim
        }
    }

    component Stat: ColumnLayout {
        property var value
        property string label

        Layout.fillWidth: true
        spacing: 1

        Text {
            text: parent.value
            font.family: Theme.font
            font.pixelSize: 16
            font.bold: true
            color: Theme.fg
        }

        Text {
            text: parent.label
            font.family: Theme.font
            font.pixelSize: 10
            color: Theme.dim
        }
    }
}
