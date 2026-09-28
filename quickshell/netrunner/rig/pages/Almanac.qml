import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"

// 05 ALMANAC 暦: the month (scroll or ‹ › to move; today in red), the weather now and the week,
// sunrise and sunset, tonight's moon.
Column {
    id: root

    spacing: 22
    Component.onCompleted: Weather.refreshIfStale()
    SystemClock { id: clock; precision: SystemClock.Minutes }

    property int offset: 0
    readonly property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth() + offset, 1)
    function moonPhase(d) {
        const days = (d.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        const p = (days / 29.530588853) % 1;
        return p < 0 ? p + 1 : p;
    }
    function moonName(p) {
        return ["new moon", "waxing crescent", "first quarter", "waxing gibbous", "full moon", "waning gibbous", "last quarter", "waning crescent"][Math.round(p * 8) % 8];
    }

    Section {
        title: Qt.formatDate(root.shown, "MMMM yyyy")
        jp: "暦"
        trailing: root.offset === 0 ? Qt.formatDate(clock.date, "dddd dd") : ""
        Row {
            spacing: 6
            Btn { text: "‹"; onClicked: root.offset-- }
            Btn { text: "today"; enabled: root.offset !== 0; onClicked: root.offset = 0 }
            Btn { text: "›"; onClicked: root.offset++ }
        }
        Grid {
            columns: 7
            width: parent.width
            readonly property real cell: width / 7
            Repeater {
                model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
                Label { required property var modelData; width: parent.cell; height: 22; horizontalAlignment: Text.AlignHCenter; text: modelData }
            }
            Repeater {
                model: 42
                Item {
                    required property int index
                    readonly property int lead: (root.shown.getDay() + 6) % 7
                    readonly property int day: index - lead + 1
                    readonly property int days: new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 0).getDate()
                    readonly property bool inMonth: day >= 1 && day <= days
                    readonly property bool today: inMonth && root.offset === 0 && day === clock.date.getDate()
                    width: parent.cell
                    height: 30
                    Rectangle { anchors.centerIn: parent; width: 30; height: 24; visible: parent.today; color: Theme.alpha(Theme.red, 0.2); border.width: 1; border.color: Theme.red }
                    Text {
                        anchors.centerIn: parent
                        visible: parent.inMonth
                        text: String(parent.day).padStart(2, "0")
                        color: parent.today ? Theme.red : index % 7 >= 5 ? Theme.cyan : Theme.fg
                        font.family: Theme.mono
                        font.pixelSize: Theme.data
                    }
                }
            }
        }
        WheelHandler { onWheel: e => root.offset += e.angleDelta.y < 0 ? 1 : -1 }
    }

    Section {
        title: "weather" + (Weather.place ? "  //  " + Weather.place : "")
        jp: "天気"
        trailing: Weather.loading ? "fetching…" : Weather.ready ? "synced " + Qt.formatTime(Weather.updated, "HH:mm") : ""
        Label { visible: Weather.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Weather.error; color: Theme.red }
        Row {
            visible: Weather.ready
            spacing: 18
            Text { text: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.isDay) : ""; color: Theme.cyan; font.family: Theme.mono; font.pixelSize: 44 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""; color: Theme.bright; font.family: Theme.display; font.pixelSize: 40; font.weight: Font.Bold }
                Label { text: Weather.ready ? Weather.describe(Weather.current.code) : ""; color: Theme.cyan }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Label { text: Weather.ready ? "feels " + Math.round(Weather.current.feels) + "°  //  hum " + Weather.current.humidity + "%" : "" }
                Label { text: Weather.ready ? "wind " + Math.round(Weather.current.wind) + " " + Weather.windLabel : "" }
                Label { text: Weather.ready ? "sun " + Qt.formatTime(Weather.sunrise, "HH:mm") + " – " + Qt.formatTime(Weather.sunset, "HH:mm") : "" }
            }
        }
        Repeater {
            model: Weather.daily
            Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 22
                readonly property real lo: Math.min(...Weather.daily.map(d => d.min))
                readonly property real hi: Math.max(...Weather.daily.map(d => d.max))
                Label { width: 50; text: index === 0 ? "today" : Qt.formatDate(modelData.date, "ddd"); color: index === 0 ? Theme.red : Theme.fg }
                Text { x: 56; anchors.verticalCenter: parent.verticalCenter; text: Weather.icon(modelData.code, true); color: Theme.cyan; font.family: Theme.mono; font.pixelSize: 15 }
                Label { x: 84; width: 40; text: modelData.pop > 0 ? modelData.pop + "%" : ""; color: Theme.cyan }
                Label { x: 128; width: 34; horizontalAlignment: Text.AlignRight; text: Math.round(modelData.min) + "°" }
                // the range bar
                Item {
                    x: 172; width: parent.width - 220; height: parent.height
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2; color: Theme.alpha(Theme.dim, 0.3) }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real span: Math.max(1, hi - lo)
                        x: (modelData.min - lo) / span * parent.width
                        width: Math.max(4, (modelData.max - modelData.min) / span * parent.width)
                        height: 4
                        color: Theme.red
                    }
                }
                Label { anchors.right: parent.right; text: Math.round(modelData.max) + "°"; strong: true }
            }
        }
    }

    Section {
        title: "moon"
        jp: "月"
        trailing: Math.round((1 - Math.cos(2 * Math.PI * root.moonPhase(clock.date))) / 2 * 100) + "% lit"
        Row {
            spacing: 16
            Canvas {
                id: moon
                width: 56; height: 56
                readonly property real p: root.moonPhase(clock.date)
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const r = 24, cx = 28, cy = 28;
                    ctx.fillStyle = Theme.bgDark;
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill();
                    const k = Math.cos(2 * Math.PI * p), waxing = p < 0.5;
                    ctx.fillStyle = Theme.cyan;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
                    ctx.save(); ctx.translate(cx, cy); ctx.scale(Math.abs(k), 1);
                    ctx.arc(0, 0, r, Math.PI / 2, -Math.PI / 2, (k > 0) === waxing);
                    ctx.restore(); ctx.closePath(); ctx.fill();
                    ctx.strokeStyle = Theme.red; ctx.lineWidth = 1;
                    ctx.beginPath(); ctx.arc(cx, cy, r + 3, 0, 2 * Math.PI); ctx.stroke();
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Label { text: root.moonName(moon.p); strong: true; color: Theme.bright }
                Label { text: "day " + Math.floor(moon.p * 29.53) + " of 29.5" }
            }
        }
    }
}
