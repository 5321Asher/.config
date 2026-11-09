import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"

// CALENDAR: the month in Doto (wheel or ‹ › to move; today the white disc), the weather now as a
// dot-matrix glyph and the week, sunrise and sunset, and tonight's moon drawn in dots.
Column {
    id: root

    spacing: 40
    Component.onCompleted: Weather.refreshIfStale()
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")

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

    // the month
    Column {
        width: root.width
        spacing: 18
        Item {
            width: parent.width
            height: 70
            Row {
                spacing: 18
                Num { anchors.baseline: yr.baseline; text: root.en.monthName(root.shown.getMonth()).toUpperCase(); font.pixelSize: 64 }
                Lb { id: yr; y: 40; text: root.shown.getFullYear() }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                Btn { glyph: "\u{F0141}"; onClicked: root.offset-- }
                Btn { text: "today"; enabled: root.offset !== 0; onClicked: root.offset = 0 }
                Btn { glyph: "\u{F0142}"; onClicked: root.offset++ }
            }
        }
        Grid {
            columns: 7
            width: parent.width
            readonly property real cell: width / 7
            Repeater {
                model: ["m", "t", "w", "t", "f", "s", "s"]
                Lb { required property var modelData; width: parent.cell; height: 30; horizontalAlignment: Text.AlignHCenter; text: modelData }
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
                    height: 54
                    Rectangle { anchors.centerIn: parent; width: 46; height: 46; radius: 23; visible: parent.today; color: Theme.fg }
                    Text {
                        anchors.centerIn: parent
                        visible: parent.inMonth
                        text: parent.day
                        color: parent.today ? Theme.ink : index % 7 >= 5 ? Theme.grey : Theme.fg
                        font { family: Theme.ui; pixelSize: 18; weight: parent.today ? Font.DemiBold : Font.Normal }
                    }
                }
            }
        }
        WheelHandler { onWheel: e => root.offset += e.angleDelta.y < 0 ? 1 : -1 }
    }

    // the weather
    Section {
        title: "weather" + (Weather.place ? "  ·  " + Weather.place : "")
        trailing: Weather.loading ? "fetching…" : Weather.ready ? "updated " + Qt.formatTime(Weather.updated, "HH:mm") : ""
        Lb { visible: Weather.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Weather.error; color: Theme.red }
        Row {
            visible: Weather.ready
            spacing: 34
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.isDay) : ""
                font.pixelSize: 120
                layer.enabled: true
                layer.effect: Dm { step: 5 }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Num { text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""; font.pixelSize: 110 }
                Lb { topPadding: 10; text: Weather.ready ? Weather.describe(Weather.current.code) : "" ; color: Theme.fg }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Lb { text: Weather.ready ? "feels " + Math.round(Weather.current.feels) + "°  ·  humidity " + Weather.current.humidity + "%" : "" }
                Lb { text: Weather.ready ? "wind " + Math.round(Weather.current.wind) + " " + Weather.windLabel : "" }
                Lb { text: Weather.ready ? "sun " + Qt.formatTime(Weather.sunrise, "HH:mm") + " – " + Qt.formatTime(Weather.sunset, "HH:mm") : "" }
            }
        }
        // the week: a column per day, the range as a strip of dots
        Row {
            visible: Weather.ready
            width: parent.width
            readonly property real lo: Math.min(...(Weather.daily ?? []).map(d => d.min))
            readonly property real hi: Math.max(...(Weather.daily ?? []).map(d => d.max))
            Repeater {
                model: Weather.daily
                Column {
                    required property var modelData
                    required property int index
                    width: parent.width / Math.max(1, Weather.daily.length)
                    spacing: 10
                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? "today" : root.en.toString(modelData.date, "ddd"); color: index === 0 ? Theme.fg : Theme.grey; px: 10 }
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.icon(modelData.code, true); font.pixelSize: 30; layer.enabled: true; layer.effect: Dm { step: 2.5 } }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.max) + "°"; color: Theme.fg; font { family: Theme.ui; pixelSize: 17 } }
                    // the day's range on the week's scale, as a column of dots
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3
                        readonly property real span: Math.max(1, parent.parent.hi - parent.parent.lo)
                        Repeater {
                            model: 10
                            Rectangle {
                                required property int index
                                readonly property real v: parent.parent.parent.hi - (index + 0.5) / 10 * parent.span
                                width: 5
                                height: 5
                                radius: 2.5
                                color: v <= modelData.max && v >= modelData.min ? Theme.fg : Theme.s3
                            }
                        }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.min) + "°"; color: Theme.grey; font { family: Theme.ui; pixelSize: 15 } }
                    Lb { anchors.horizontalCenter: parent.horizontalCenter; visible: modelData.pop > 0; text: modelData.pop + "%"; px: 9 }
                }
            }
        }
    }

    // the moon, in dots
    Section {
        title: "moon"
        trailing: Math.round((1 - Math.cos(2 * Math.PI * root.moonPhase(clock.date))) / 2 * 100) + "% lit"
        Row {
            spacing: 30
            Grid {
                id: moon
                readonly property real p: root.moonPhase(clock.date)
                readonly property int n: 15
                columns: n
                spacing: 3
                Repeater {
                    model: moon.n * moon.n
                    Rectangle {
                        required property int index
                        readonly property real x_: ((index % moon.n) + 0.5) / moon.n * 2 - 1
                        readonly property real y_: (Math.floor(index / moon.n) + 0.5) / moon.n * 2 - 1
                        readonly property bool inside: x_ * x_ + y_ * y_ <= 1
                        // lit: the terminator is an ellipse; waxing lights the right side
                        readonly property real edge: Math.cos(2 * Math.PI * moon.p) * Math.sqrt(Math.max(0, 1 - y_ * y_))
                        readonly property bool lit: inside && (moon.p < 0.5 ? x_ > edge : x_ < -edge)
                        width: 7
                        height: 7
                        radius: 3.5
                        color: !inside ? "transparent" : lit ? Theme.fg : Theme.s3
                    }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text { text: root.moonName(moon.p); color: Theme.fg; font { family: Theme.ui; pixelSize: 22 } }
                Lb { text: "day " + Math.floor(moon.p * 29.53) + " of 29.5" }
            }
        }
    }
}
