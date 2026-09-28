import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"

// V. Almanac: the month (scroll or ‹ › to leaf through; today ringed in red ink, Sundays in red as
// in an old calendar), the weather now and for the week, the sun's rising and setting, tonight's moon.
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
        return ["the new moon", "a waxing crescent", "the first quarter", "a waxing gibbous", "the full moon", "a waning gibbous", "the last quarter", "a waning crescent"][Math.round(p * 8) % 8];
    }

    Section {
        title: Qt.formatDate(root.shown, "MMMM") + " " + Theme.roman(root.shown.getFullYear())
        trailing: root.offset === 0 ? Qt.formatDate(clock.date, "dddd") + " the " + Theme.ordinal(clock.date.getDate()) : ""
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
                Caps { required property var modelData; required property int index; width: parent.cell; height: 24; horizontalAlignment: Text.AlignHCenter
                       text: modelData; color: index === 6 ? Theme.rubric : Theme.inkDim }
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
                    height: 32
                    Rectangle { anchors.centerIn: parent; width: 30; height: 30; radius: 15; visible: parent.today; color: "transparent"
                                border.width: 1.5; border.color: Theme.rubric; rotation: -8 }
                    Body {
                        anchors.centerIn: parent
                        visible: parent.inMonth
                        text: parent.day
                        strong: parent.today
                        color: parent.today ? Theme.rubric : index % 7 === 6 ? Theme.rubric : Theme.ink
                    }
                }
            }
        }
        WheelHandler { onWheel: e => root.offset += e.angleDelta.y < 0 ? 1 : -1 }
    }

    Section {
        title: "the weather" + (Weather.place ? " at " + Weather.place : "")
        trailing: Weather.loading ? "reading the sky…" : Weather.ready ? "read at " + Qt.formatTime(Weather.updated, "h:mm") : ""
        Body { visible: Weather.error !== ""; width: parent.width; wrapMode: Text.Wrap; text: Weather.error; color: Theme.danger; italic: true }
        Row {
            visible: Weather.ready
            spacing: 18
            Glyph { text: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.isDay) : ""; color: Theme.goldDeep; font.pixelSize: 46 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""; color: Theme.ink; font.family: Theme.uncial; font.pixelSize: 40 }
                Body { text: Weather.ready ? Weather.describe(Weather.current.code) : ""; italic: true; color: Theme.inkDim }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Body { text: Weather.ready ? "feels " + Math.round(Weather.current.feels) + "° · damp " + Weather.current.humidity + "%" : ""; font.pixelSize: 14 }
                Body { text: Weather.ready ? "wind " + Math.round(Weather.current.wind) + " " + Weather.windLabel : ""; font.pixelSize: 14 }
                Body { text: Weather.ready ? "sun " + Qt.formatTime(Weather.sunrise, "h:mm") + " – " + Qt.formatTime(Weather.sunset, "h:mm") : ""; font.pixelSize: 14 }
            }
        }
        Repeater {
            model: Weather.daily
            Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 24
                readonly property real lo: Math.min(...Weather.daily.map(d => d.min))
                readonly property real hi: Math.max(...Weather.daily.map(d => d.max))
                Body { width: 56; anchors.verticalCenter: parent.verticalCenter; text: index === 0 ? "today" : Qt.formatDate(modelData.date, "dddd").slice(0, 3)
                       italic: true; color: index === 0 ? Theme.rubric : Theme.ink }
                Glyph { x: 60; anchors.verticalCenter: parent.verticalCenter; text: Weather.icon(modelData.code, true); color: Theme.goldDeep }
                Body { x: 88; width: 40; anchors.verticalCenter: parent.verticalCenter; text: modelData.pop > 0 ? modelData.pop + "%" : ""; color: Theme.inkDim; font.pixelSize: 13 }
                Body { x: 130; width: 34; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: Math.round(modelData.min) + "°"; color: Theme.inkDim }
                Item {
                    x: 174; width: parent.width - 222; height: parent.height
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.alpha(Theme.inkDim, 0.4) }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property real span: Math.max(1, hi - lo)
                        x: (modelData.min - lo) / span * parent.width
                        width: Math.max(6, (modelData.max - modelData.min) / span * parent.width)
                        height: 5; radius: 2.5
                        gradient: Gradient { orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.goldDeep } GradientStop { position: 1; color: Theme.rubric } }
                    }
                }
                Body { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Math.round(modelData.max) + "°"; strong: true }
            }
        }
    }

    Section {
        title: "the moon"
        trailing: Math.round((1 - Math.cos(2 * Math.PI * root.moonPhase(clock.date))) / 2 * 100) + "% lit"
        Row {
            spacing: 16
            Moon { size: 56; lit: Theme.gold; dark: Theme.alpha(Theme.ink, 0.85); rim: Theme.ink }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Body { text: "Tonight, " + root.moonName(root.moonPhase(clock.date)) + "."; strong: true }
                Body { text: "the " + Theme.ordinal(Math.floor(root.moonPhase(clock.date) * 29.53) + 1) + " day of her twenty-nine and a half"; italic: true; color: Theme.inkDim; font.pixelSize: 14 }
            }
        }
    }
}
