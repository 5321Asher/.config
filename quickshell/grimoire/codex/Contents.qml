import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../widgets"
import "../services"

// The codex's left page: "Codex" in blackletter, the chapters as a contents page (a red numeral,
// the name in uncials, a dotted leader and its folio), the one you're reading washed in gold with a
// ❧ in the margin; at the foot, the day, the moon and how long the candle has burned.
Item {
    id: root

    SystemClock { id: clock; precision: SystemClock.Minutes }
    property real uptime: 0
    FileView { id: up; path: "/proc/uptime"; onLoaded: root.uptime = parseFloat(text().split(" ")[0]) || 0 }
    Timer { running: true; repeat: true; interval: 60000; onTriggered: up.reload() }

    Column {
        x: 34; y: 26
        width: parent.width - 34 - 50
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Codex"
            color: Theme.ink
            font.family: Theme.blackletter
            font.pixelSize: 48
        }
        Body {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "being the book of this machine"
            italic: true
            color: Theme.inkDim
            font.pixelSize: 14
        }
        GoldRule { width: parent.width; color: Theme.alpha(Theme.inkDim, 0.6); ornament: "❦" }
        Item { width: 1; height: 6 }

        Repeater {
            model: CodexState.pages
            Item {
                id: entry
                required property var modelData
                required property int index
                readonly property bool here: CodexState.page === modelData.id
                width: parent.width
                height: 36
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    radius: 3
                    color: entry.here ? Theme.alpha(Theme.rubric, 0.09) : mouse.containsMouse ? Theme.alpha(Theme.ink, 0.05) : "transparent"
                }
                Text {
                    visible: entry.here
                    x: -12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "❧"
                    color: Theme.rubric
                    font.family: Theme.symbols
                    font.pixelSize: 13
                }
                Text {
                    id: num
                    x: 10
                    width: 44
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.roman(entry.index + 1) + "."
                    color: Theme.rubric
                    font.family: Theme.display; font.weight: Font.DemiBold
                    font.pixelSize: 15
                }
                Text {
                    id: name
                    x: 58
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.title
                    color: Theme.ink
                    font.family: Theme.display; font.weight: Font.DemiBold
                    font.pixelSize: 17
                }
                Text {
                    anchors.baseline: name.baseline
                    x: name.x + name.width + 8
                    width: Math.max(0, folio.x - x - 8)
                    clip: true
                    text: "· ".repeat(80)
                    color: Theme.alpha(Theme.inkDim, 0.5)
                    font.family: Theme.body
                    font.pixelSize: Theme.small
                }
                Body {
                    id: folio
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.baseline: name.baseline
                    text: Theme.roman(entry.index * 2 + 3).toLowerCase()
                    italic: true
                    color: Theme.inkDim
                    font.pixelSize: 14
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CodexState.turnTo(entry.modelData.id)
                }
            }
        }
    }

    // the foot of the page
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        spacing: 6
        GoldRule { anchors.horizontalCenter: parent.horizontalCenter; width: 220; color: Theme.alpha(Theme.inkDim, 0.5); ornament: "✦" }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Moon { anchors.verticalCenter: parent.verticalCenter; size: 16; lit: Theme.gold; dark: Theme.alpha(Theme.ink, 0.8); rim: Theme.ink }
            Body {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(clock.date, "dddd") + ", the " + Theme.ordinal(clock.date.getDate()) + " of " + Qt.formatDate(clock.date, "MMMM")
                italic: true
                color: Theme.inkDim
                font.pixelSize: 14
            }
        }
        Body {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const m = Math.floor(root.uptime / 60), h = Math.floor(m / 60);
                return "the candle has burned " + (h ? h + (h === 1 ? " hour " : " hours ") : "") + (m % 60) + " minutes";
            }
            italic: true
            color: Theme.inkDim
            font.pixelSize: 13
        }
    }
}
