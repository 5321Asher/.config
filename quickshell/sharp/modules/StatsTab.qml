import QtQuick
import QtQuick.Layouts
import Quickshell

// CPU / GPU gauges, activity chart, threads, memory, storage, network
Flickable {
    id: root

    readonly property var d: SysStats.data
    readonly property var cpu: d?.cpu ?? null
    readonly property var gpu: d?.gpu ?? null
    readonly property var mem: d?.mem ?? null

    function deg(t) {
        return Math.round(t) + "°";
    }

    function gb(n) {
        return (n / 1024 ** 3).toFixed(1);
    }

    // Asks the panel to close (before opening btop)
    signal closeRequested

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Text {
        anchors.centerIn: parent
        visible: !root.d
        text: "Reading sensors…"
        font.family: Theme.font
        font.pixelSize: 13
        color: Theme.dim
    }

    ColumnLayout {
        id: content

        width: root.width
        visible: !!root.d
        spacing: 10

        // CPU + GPU
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            GaugeCard {
                title: "CPU"
                subtitle: root.cpu?.name ?? ""
                value: (root.cpu?.usage ?? 0) / 100
                accent: Theme.accent
                temp: root.cpu?.temp ?? 0
                detail: (root.cpu?.freq ?? 0).toFixed(2) + " GHz"
            }

            GaugeCard {
                title: "GPU"
                subtitle: root.gpu?.name ?? "Not found"
                value: (root.gpu?.usage ?? 0) / 100
                accent: Theme.purple
                temp: root.gpu?.temp ?? 0
                detail: Math.round(root.gpu?.power ?? 0) + " W"
            }
        }

        // Usage over time
        Card {
            title: "Activity"
            trailing: (SysStats.historyLength * SysStats.interval / 60) + " min"

            Item {
                Layout.fillWidth: true
                implicitHeight: 80

                // Grid lines at 25% steps
                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        y: parent.height * (index + 1) / 4
                        width: parent.width
                        height: 1
                        color: Theme.hover
                        opacity: 0.5
                    }
                }

                Sparkline {
                    anchors.fill: parent
                    values: SysStats.gpuHistory
                    max: 100
                    color: Theme.purple
                }

                Sparkline {
                    anchors.fill: parent
                    values: SysStats.cpuHistory
                    max: 100
                    color: Theme.accent
                }
            }

            RowLayout {
                spacing: 14

                Legend { color: Theme.accent; label: "CPU  " + Math.round(root.cpu?.usage ?? 0) + "%" }
                Legend { color: Theme.purple; label: "GPU  " + Math.round(root.gpu?.usage ?? 0) + "%" }
            }
        }

        // Per-thread load
        Card {
            title: "Threads"
            trailing: "load " + (root.cpu?.load ?? []).map(l => l.toFixed(2)).join("  ")

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.cpu?.threads ?? []

                    ColumnLayout {
                        required property real modelData
                        required property int index

                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 0
                            color: Theme.hover

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(4, parent.height * parent.parent.modelData / 100)
                                radius: 0
                                color: Theme.accent
                                opacity: 0.5 + parent.parent.modelData / 200

                                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: parent.index
                            font.family: Theme.font
                            font.pixelSize: 9
                            color: Theme.dim
                        }
                    }
                }
            }
        }

        // Memory
        Card {
            title: "Memory"

            UsageBar {
                label: "RAM"
                used: root.mem?.used ?? 0
                total: root.mem?.total ?? 1
                text: root.gb(used) + " / " + root.gb(total) + " GB"
            }

            UsageBar {
                visible: (root.gpu?.memTotal ?? 0) > 0
                label: "VRAM"
                used: root.gpu?.memUsed ?? 0
                total: root.gpu?.memTotal ?? 1
                color: Theme.purple
                text: root.gb(used) + " / " + root.gb(total) + " GB"
            }

            UsageBar {
                visible: (root.mem?.swapTotal ?? 0) > 0
                label: "Swap"
                used: root.mem?.swapUsed ?? 0
                total: root.mem?.swapTotal ?? 1
                color: Theme.accentMuted
                text: root.gb(used) + " / " + root.gb(total) + " GB"
            }
        }

        // Storage
        Card {
            title: "Storage"

            Repeater {
                model: root.d?.disks ?? []

                UsageBar {
                    required property var modelData
                    label: modelData.mount
                    used: modelData.used
                    total: modelData.size
                    text: SysStats.bytes(used, 0) + " / " + SysStats.bytes(total, 0)
                }
            }

            Repeater {
                model: root.d?.drives ?? []

                RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: String.fromCodePoint(0xF02CA)
                        font.family: Theme.font
                        font.pixelSize: 14
                        color: Theme.dim
                    }

                    Text {
                        Layout.fillWidth: true
                        text: parent.modelData.model
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.fg
                    }

                    TempChip { temp: parent.modelData.temp }
                }
            }
        }

        // Network + system
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Card {
                Layout.fillHeight: true
                title: "Network"
                trailing: root.d?.net.iface ?? ""

                NetRate {
                    icon: ""
                    rate: root.d?.net.rx ?? 0
                    history: SysStats.rxHistory
                    color: Theme.accent
                }

                NetRate {
                    icon: ""
                    rate: root.d?.net.tx ?? 0
                    history: SysStats.txHistory
                    color: Theme.purple
                }
            }

            Card {
                Layout.preferredWidth: 150
                Layout.fillWidth: false
                Layout.fillHeight: true
                title: "System"

                InfoRow { label: "Processes"; value: root.d?.procs ?? "" }
                InfoRow { label: "GPU fan"; value: Math.round(root.gpu?.fan ?? 0) + "%" }
                InfoRow { label: "GPU clock"; value: Math.round(root.gpu?.clock ?? 0) + " MHz" }
                InfoRow { label: "GPU power"; value: Math.round(root.gpu?.powerLimit ?? 0) + " W max" }
            }
        }

        // Security: packages with known vulnerabilities (arch-audit) and updates waiting (checkupdates)
        Card {
            title: "Security"
            trailing: !Updates.auditAvailable ? "arch-audit not installed"
                : Updates.count + " affected" + (Updates.auditAt ? "  ·  " + Updates.ago() : "")
            trailingColor: Updates.high > 0 ? Theme.danger : Updates.count > 0 ? Theme.warn : Theme.green

            RowLayout {
                Layout.fillWidth: true
                visible: Updates.auditAvailable
                spacing: 8
                Repeater {
                    model: [["High", Updates.high, Theme.danger], ["Medium", Updates.bySeverity.Medium ?? 0, Theme.warn],
                            ["Low", Updates.bySeverity.Low ?? 0, Theme.dim]]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 26
                        color: "transparent"
                        border.width: 1
                        border.color: modelData[1] > 0 ? modelData[2] : Theme.border
                        Text {
                            anchors.centerIn: parent
                            text: modelData[0] + "  " + modelData[1]
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.bold: true
                            color: modelData[1] > 0 ? modelData[2] : Theme.dim
                        }
                    }
                }
            }
            Repeater {
                model: Updates.vulns.slice(0, 5)
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { implicitWidth: 6; implicitHeight: 6
                                color: modelData.severity === "Critical" || modelData.severity === "High" ? Theme.danger
                                     : modelData.severity === "Medium" ? Theme.warn : Theme.dim }
                    Text { text: modelData.name; font.family: Theme.font; font.pixelSize: 11; font.bold: true; color: Theme.fg }
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.type; font.family: Theme.font; font.pixelSize: 11; color: Theme.dim }
                    Text { text: modelData.cves + " CVE"; font.family: Theme.font; font.pixelSize: 11; color: Theme.dim }
                    Text { Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight; text: modelData.fix ? "fix ready" : "no fix"
                           font.family: Theme.font; font.pixelSize: 11; color: modelData.fix ? Theme.green : Theme.dim }
                }
            }
            Text {
                visible: Updates.count > 5
                text: "+" + (Updates.count - 5) + " more  ·  " + Updates.fixable + " fixed by updating"
                font.family: Theme.font; font.pixelSize: 11; color: Theme.dim
            }
            InfoRow {
                label: "Updates pending"
                value: Updates.pendingAvailable ? (Updates.checking ? "checking…" : Updates.pending) : "install pacman-contrib"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                SmallButton { label: Updates.auditing || Updates.checking ? "Scanning…" : "Scan again"; onClicked: Updates.sweep() }
                SmallButton { label: "Update now"; enabled: Updates.pending > 0; onClicked: { root.closeRequested(); Updates.update(); } }
            }
        }

        // Everything else: btop
        Rectangle {
            Layout.alignment: Qt.AlignRight
            implicitWidth: btopText.implicitWidth + 24
            implicitHeight: 26
            radius: 0
            color: btopMouse.containsMouse ? Theme.surface : "transparent"
            border.width: 1
            border.color: btopMouse.containsMouse ? Theme.accent : Theme.border

            Text {
                id: btopText
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF0128) + "  Open btop"
                font.family: Theme.font
                font.pixelSize: 11
                color: btopMouse.containsMouse ? Theme.accent : Theme.dim
            }

            MouseArea {
                id: btopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.closeRequested();
                    Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]);
                }
            }
        }
    }

    // --- Components ---

    component Card: Rectangle {
        id: card

        property string title
        property string trailing
        property color trailingColor: Theme.border
        default property alias items: body.data

        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        radius: 0
        color: Theme.bgDark
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: col

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: card.title
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                    color: Theme.dim
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: card.trailing
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: card.trailingColor
                }
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 10
            }
        }
    }

    component GaugeCard: Rectangle {
        id: gaugeCard

        property string title
        property string subtitle
        property real value
        property color accent
        property real temp
        property string detail

        Layout.fillWidth: true
        implicitHeight: 212
        radius: 0
        color: Theme.bgDark
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: gaugeCard.title
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    color: gaugeCard.accent
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: gaugeCard.subtitle
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.dim
                }
            }

            Gauge {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 112
                implicitHeight: 112
                value: gaugeCard.value
                color: gaugeCard.accent

                Column {
                    anchors.centerIn: parent

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Math.round(gaugeCard.value * 100) + "%"
                        font.family: Theme.font
                        font.pixelSize: 24
                        font.bold: true
                        color: Theme.fg
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "usage"
                        font.family: Theme.font
                        font.pixelSize: 10
                        color: Theme.dim
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                TempChip { temp: gaugeCard.temp }

                Item { Layout.fillWidth: true }

                Text {
                    text: gaugeCard.detail
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.fg
                }
            }
        }
    }

    component TempChip: Rectangle {
        id: chip

        property real temp
        readonly property color tint: SysStats.tempColor(temp)

        implicitWidth: chipRow.implicitWidth + 14
        implicitHeight: 22
        radius: 0
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.15)

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: String.fromCodePoint(0xF050F)
                font.family: Theme.font
                font.pixelSize: 12
                color: chip.tint
            }

            Text {
                text: root.deg(chip.temp) + "C"
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: true
                color: chip.tint
            }
        }
    }

    component UsageBar: ColumnLayout {
        id: ub

        property string label
        property real used
        property real total: 1
        property string text
        property color color: Theme.accent
        readonly property real ratio: total > 0 ? Math.min(1, used / total) : 0

        Layout.fillWidth: true
        spacing: 5

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: ub.label
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true
                color: Theme.fg
            }

            Text {
                text: Math.round(ub.ratio * 100) + "%"
                font.family: Theme.font
                font.pixelSize: 11
                color: ub.color
            }

            Item { Layout.fillWidth: true }

            Text {
                text: ub.text
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 0
            color: Theme.hover

            Rectangle {
                width: Math.max(height, parent.width * ub.ratio)
                height: parent.height
                radius: 0
                color: ub.color

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    component NetRate: RowLayout {
        id: nr

        property string icon
        property real rate
        property var history
        property color color

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: nr.icon
            font.family: Theme.font
            font.pixelSize: 11
            color: nr.color
        }

        Text {
            Layout.preferredWidth: 70
            text: SysStats.bytes(nr.rate) + "/s"
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
            color: Theme.fg
        }

        Sparkline {
            Layout.fillWidth: true
            implicitHeight: 24
            values: nr.history
            color: nr.color
            lineWidth: 1.5
        }
    }

    component Legend: Row {
        property color color
        property string label

        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 0
            color: parent.color
        }

        Text {
            text: parent.label
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.dim
        }
    }

    component SmallButton: Rectangle {
        id: sb
        property string label
        signal clicked()
        implicitWidth: sbText.implicitWidth + 24
        implicitHeight: 26
        opacity: enabled ? 1 : 0.4
        color: sbMouse.containsMouse ? Theme.surface : "transparent"
        border.width: 1
        border.color: sbMouse.containsMouse ? Theme.accent : Theme.border
        Text { id: sbText; anchors.centerIn: parent; text: sb.label; font.family: Theme.font; font.pixelSize: 11
               color: sbMouse.containsMouse ? Theme.accent : Theme.dim }
        MouseArea { id: sbMouse; anchors.fill: parent; hoverEnabled: true; enabled: sb.enabled
                    cursorShape: Qt.PointingHandCursor; onClicked: sb.clicked() }
    }

    component InfoRow: RowLayout {
        property string label
        property var value

        Layout.fillWidth: true

        Text {
            text: parent.label
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.dim
        }

        Item { Layout.fillWidth: true }

        Text {
            text: parent.value
            font.family: Theme.font
            font.pixelSize: 11
            font.bold: true
            color: Theme.fg
        }
    }
}
