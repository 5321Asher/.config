import QtQuick
import Quickshell
import "../theme"
import "../widgets"
import "../services"
import "../settings"

// Widgets (the weather at the left of the taskbar, Windows + W): a board of cards down the left.
// Weather now and the week, tonight's moon, the machine (processor, memory, graphics), Claude's
// usage limits, and Windows Update (vulnerabilities and updates waiting). Click a card for its
// Settings page.
Item {
    id: root

    required property string screenName
    property bool active: false
    onActiveChanged: {
        SysStats.active = active;
        if (active) { Weather.refreshIfStale(); ClaudeStatus.refreshIfStale(); }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var d: SysStats.data
    function moonPhase(t) {
        const days = (t.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        const p = (days / 29.530588853) % 1;
        return p < 0 ? p + 1 : p;
    }
    function moonName(p) {
        return ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous",
                "Last quarter", "Waning crescent"][Math.round(p * 8) % 8];
    }
    function go(page) { Flyouts.close(); SettingsApp.open(page); }

    Acrylic { anchors.fill: parent; tintAlpha: Theme.dark ? 0.8 : 0.75 }

    Txt { x: 24; y: 20; text: Qt.formatTime(clock.date, "h:mm AP"); size: Theme.subtitle; strong: true }
    Txt { x: 24; y: 48; text: Qt.formatDate(clock.date, "dddd, MMMM d"); level: 2 }
    Btn { anchors.right: parent.right; anchors.rightMargin: 16; y: 20; kind: "subtle"; glyph: ""; width: 36; onClicked: root.go("time") }

    Scroll {
        x: 16; y: 84
        width: parent.width - 32
        height: parent.height - y - 16

        Flow {
            id: flow
            width: parent.width
            spacing: 12
            readonly property real col: (width - spacing) / 2

            // ---------------------------------------------------- weather
            Widget {
                width: flow.col; height: 216
                title: Weather.place || "Weather"; glyph: ""
                onOpened: root.go("time")
                Item {
                    anchors.fill: parent
                    Txt { visible: !Weather.ready; anchors.centerIn: parent; text: Weather.error || "Getting the weather…"; level: 2; width: parent.width - 20; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
                    Row {
                        visible: Weather.ready
                        spacing: 12
                        WeatherIcon { size: 64; code: Weather.current?.code ?? 0; day: Weather.current?.isDay ?? true }
                        Txt { height: 64; text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""; size: Theme.titleLarge; font.weight: Font.Light }
                    }
                    Column {
                        visible: Weather.ready
                        y: 76
                        width: parent.width
                        Txt { text: Weather.ready ? Weather.describe(Weather.current.code) : ""; strong: true }
                        Txt { text: Weather.ready ? "Feels like " + Math.round(Weather.current.feels) + "°  ·  Humidity " + Weather.current.humidity + "%" : ""; level: 2; size: Theme.caption }
                        Txt { text: Weather.ready ? "Wind " + Math.round(Weather.current.wind) + " " + Weather.windLabel : ""; level: 2; size: Theme.caption }
                        Txt { text: Weather.ready ? "Sunrise " + Qt.formatTime(Weather.sunrise, "h:mm AP") + "  ·  Sunset " + Qt.formatTime(Weather.sunset, "h:mm AP") : ""; level: 2; size: Theme.caption }
                    }
                }
            }

            // ---------------------------------------------------- tonight's moon
            Widget {
                width: flow.col; height: 216
                title: "Moon"; glyph: ""
                Canvas {
                    id: moon
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 96; height: 96
                    readonly property real p: root.moonPhase(clock.date)
                    onPChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const r = 44, cx = 48, cy = 48;
                        ctx.fillStyle = Theme.dark ? "#303030" : "#d6d6d6";
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill();
                        const k = Math.cos(2 * Math.PI * p), waxing = p < 0.5;
                        ctx.fillStyle = "#fff4c8";
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
                        ctx.save(); ctx.translate(cx, cy); ctx.scale(Math.abs(k), 1);
                        ctx.arc(0, 0, r, Math.PI / 2, -Math.PI / 2, (k > 0) === waxing);
                        ctx.restore();
                        ctx.closePath(); ctx.fill();
                    }
                }
                Txt { y: 108; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.moonName(moon.p); strong: true }
                Txt { y: 130; width: parent.width; horizontalAlignment: Text.AlignHCenter; level: 2; size: Theme.caption
                      text: Math.round((1 - Math.cos(2 * Math.PI * moon.p)) / 2 * 100) + "% lit · day " + Math.floor(moon.p * 29.53) }
            }

            // ---------------------------------------------------- the week
            Widget {
                width: flow.width; height: 150
                title: "Forecast"; glyph: ""
                onOpened: root.go("time")
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0
                    Repeater {
                        model: Weather.daily.slice(0, 7)
                        Column {
                            required property var modelData
                            required property int index
                            width: (flow.width - 40) / 7
                            spacing: 4
                            Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: index === 0 ? "Today" : Qt.formatDate(modelData.date, "ddd"); size: Theme.caption }
                            WeatherIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 32; code: modelData.code }
                            Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Math.round(modelData.max) + "°"; strong: true }
                            Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Math.round(modelData.min) + "°"; level: 2; size: Theme.caption }
                        }
                    }
                }
            }

            // ---------------------------------------------------- the machine
            Widget {
                width: flow.col; height: 200
                title: "System"; glyph: ""
                onOpened: root.go("performance")
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18
                    Repeater {
                        model: root.d ? [
                            ["CPU", root.d.cpu.usage / 100, Math.round(root.d.cpu.usage) + "%"],
                            ["Memory", root.d.mem.used / root.d.mem.total, Math.round(root.d.mem.used / root.d.mem.total * 100) + "%"],
                            ["GPU", (root.d.gpu?.usage ?? 0) / 100, root.d.gpu ? Math.round(root.d.gpu.usage) + "%" : "—"],
                        ] : []
                        Column {
                            required property var modelData
                            spacing: 6
                            Item {
                                width: 64; height: 64
                                Ring { anchors.fill: parent; value: modelData[1]; thickness: 5; track: Theme.subtle; color: modelData[1] > 0.9 ? Theme.danger : Theme.accent }
                                Txt { anchors.centerIn: parent; text: modelData[2]; size: Theme.caption; strong: true }
                            }
                            Txt { width: 64; horizontalAlignment: Text.AlignHCenter; text: modelData[0]; size: Theme.caption; level: 2 }
                        }
                    }
                }
                Txt {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    level: 2; size: Theme.caption
                    text: root.d ? "↓ " + SysStats.bytes(root.d.net.rx) + "/s   ↑ " + SysStats.bytes(root.d.net.tx) + "/s" : "Reading…"
                }
            }

            // ---------------------------------------------------- Claude
            Widget {
                width: flow.col; height: 200
                title: "Claude"; glyph: ""
                onOpened: root.go("accounts")
                Column {
                    width: parent.width
                    spacing: 10
                    Txt { visible: (ClaudeStatus.data?.limits ?? []).length === 0; text: ClaudeStatus.loading ? "Checking…" : "No usage limits to show."; level: 2 }
                    Repeater {
                        model: (ClaudeStatus.data?.limits ?? []).slice(0, 3)
                        Column {
                            required property var modelData
                            width: parent.width
                            spacing: 4
                            readonly property real f: (modelData.percent ?? 0) / 100
                            Item {
                                width: parent.width; height: 18
                                Txt { text: modelData.label; size: Theme.caption }
                                Txt { anchors.right: parent.right; text: Math.round(parent.parent.f * 100) + "%"; size: Theme.caption; level: 2 }
                            }
                            Progress { width: parent.width; value: parent.f; color: parent.f >= 0.9 ? Theme.danger : Theme.accent }
                            Txt { visible: !!modelData.resetsAt; text: "Resets " + ClaudeStatus.resetsIn(modelData.resetsAt ?? ""); size: Theme.caption; level: 3 }
                        }
                    }
                }
            }

            // ---------------------------------------------------- Windows Update
            Widget {
                width: flow.width; height: 110
                title: "Windows Update"; glyph: ""
                onOpened: root.go("update")
                Row {
                    spacing: 14
                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        g: Updates.high > 0 ? "" : Updates.pending > 0 ? "" : ""
                        size: 32
                        color: Updates.high > 0 ? Theme.danger : Updates.pending > 0 ? Theme.accentLink : Theme.green
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Txt {
                            strong: true
                            text: Updates.checking ? "Checking for updates…" : Updates.pending > 0 ? Updates.pending + " updates available" : "You're up to date"
                        }
                        Txt {
                            level: 2; size: Theme.caption
                            text: !Updates.auditAvailable ? "The vulnerability check (arch-audit) isn't installed"
                                : Updates.count === 0 ? "No known vulnerabilities"
                                : Updates.count + " packages with known vulnerabilities" + (Updates.high ? " · " + Updates.high + " high" : "")
                        }
                    }
                }
            }
        }
    }

    // A widget card: a small title with its glyph, content below; click to open its settings
    component Widget: Card {
        id: w
        default property alias content: box.data
        property string title
        property string glyph
        signal opened()
        color: wm.containsMouse ? Qt.alpha(Theme.cardHover, 0.95) : Qt.alpha(Theme.card, 0.9)
        MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; onClicked: w.opened() }
        Row {
            x: 16; y: 12
            spacing: 8
            Glyph { g: w.glyph; size: 12; color: Theme.text2; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: w.title; size: Theme.caption; level: 2 }
        }
        Item { id: box; x: 16; y: 40; width: parent.width - 32; height: parent.height - 52 }
    }
}
