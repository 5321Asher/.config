import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Date/Time Properties: 98's calendar and round clock, then the weather (now, the week, sunrise
// and sunset) and tonight's moon. Weather: services/Weather.qml (Open-Meteo, located by IP or
// services/Config.qml).
Props {
    id: root

    title: "Date/Time Properties"
    icon: "preferences-system-time"
    tabs: ["Date & Time", "Weather"]

    Component.onCompleted: Weather.refreshIfStale()
    // the time zone, from /etc/localtime's link (…/zoneinfo/Europe/London)
    QtObject { id: tz; property string text: "" }
    Process {
        running: true
        command: ["sh", "-c", "readlink /etc/localtime | sed 's|.*zoneinfo/||'"]
        stdout: StdioCollector { onStreamFinished: tz.text = text.trim().replace(/_/g, " ") }
    }
    SystemClock { id: clock; precision: SystemClock.Seconds }

    property int offset: 0      // months from this one (the calendar only shows; it never sets the clock)
    readonly property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth() + offset, 1)
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August",
                                   "September", "October", "November", "December"]

    // Moon phase, 0 = new .. 0.5 = full .. 1 = new (mean synodic month from a known new moon)
    function moonPhase(d) {
        const days = (d.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        const p = (days / 29.530588853) % 1;
        return p < 0 ? p + 1 : p;
    }
    function moonName(p) {
        return ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous",
                "Last Quarter", "Waning Crescent"][Math.round(p * 8) % 8];
    }
    function weatherIcon(code, day) {
        if (code <= 1) return day ? "weather-clear" : "weather-clear-night";
        if (code === 2) return day ? "weather-few-clouds" : "weather-few-clouds-night";
        if (code === 3) return "weather-overcast";
        if (code === 45 || code === 48) return "weather-fog";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "weather-snow";
        if (code >= 95) return "weather-storm";
        return "weather-showers";
    }

    // ---------------------------------------------------------------- Date & Time
    Item {
        Group {
            id: dateGroup
            title: "Date"
            width: 250

            Row {
                spacing: 6
                Combo {
                    width: 128
                    model: root.months
                    currentIndex: root.shown.getMonth()
                    onChosen: i => root.offset += i - root.shown.getMonth()
                }
                // the year, with 98's little up/down buttons
                Bevel {
                    kind: "sunken"
                    fill: Theme.window
                    width: 84
                    height: Theme.field
                    Txt { x: 6; height: parent.height; text: root.shown.getFullYear(); color: Theme.windowText }
                    Column {
                        x: parent.width - 20; y: 2
                        Btn { width: 18; implicitWidth: 18; height: 12; implicitHeight: 12; padding: 0; activeFocusOnTab: false
                              glyph: "up"; onClicked: root.offset += 12 }
                        Btn { width: 18; implicitWidth: 18; height: 12; implicitHeight: 12; padding: 0; activeFocusOnTab: false
                              glyph: "down"; onClicked: root.offset -= 12 }
                    }
                }
            }

            // the month: a white grid, S M T W T F S across the top in the title colour, today selected
            Bevel {
                kind: "sunken"
                fill: Theme.window
                width: parent.width
                height: 206
                Grid {
                    x: 4; y: 4
                    columns: 7
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        Rectangle {
                            required property var modelData
                            width: 31; height: 24
                            color: Theme.shadow
                            Txt { anchors.centerIn: parent; text: modelData; color: Theme.hilight }
                        }
                    }
                    Repeater {
                        model: 42
                        Item {
                            required property int index
                            readonly property int day: index - root.shown.getDay() + 1
                            readonly property int days: new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 0).getDate()
                            readonly property bool inMonth: day >= 1 && day <= days
                            readonly property bool today: inMonth && root.offset === 0 && day === clock.date.getDate()
                            width: 31; height: 28
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                visible: parent.today
                                color: Theme.select
                            }
                            Txt {
                                anchors.centerIn: parent
                                visible: parent.inMonth
                                text: parent.day
                                color: parent.today ? Theme.selectText : Theme.windowText
                            }
                        }
                    }
                }
            }
        }

        Group {
            title: "Time"
            x: dateGroup.width + 10
            width: parent.width - x
            height: dateGroup.height
            spacing: 14

            // the round clock: a white face, twelve hour dots, black hands, a second hand
            Canvas {
                id: face
                anchors.horizontalCenter: parent.horizontalCenter
                width: 170
                height: 170
                property var t: clock.date
                onTChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const c = width / 2, r = c - 6;
                    for (let i = 0; i < 60; i++) {
                        const a = i / 60 * 2 * Math.PI, big = i % 5 === 0;
                        const x = c + r * Math.sin(a), y = c - r * Math.cos(a);
                        if (big) {
                            ctx.fillStyle = Theme.title;
                            ctx.fillRect(Math.round(x) - 2, Math.round(y) - 2, 4, 4);
                            ctx.fillStyle = Theme.hilight;
                            ctx.fillRect(Math.round(x) - 2, Math.round(y) - 2, 2, 2);
                        } else {
                            ctx.fillStyle = Theme.shadow;
                            ctx.fillRect(Math.round(x), Math.round(y), 1, 1);
                        }
                    }
                    const d = t;
                    const hand = (a, len, w, col) => {
                        ctx.strokeStyle = col; ctx.lineWidth = w; ctx.lineCap = "square";
                        ctx.beginPath(); ctx.moveTo(c, c); ctx.lineTo(c + len * Math.sin(a), c - len * Math.cos(a)); ctx.stroke();
                    };
                    const s = d.getSeconds(), m = d.getMinutes() + s / 60, h = d.getHours() % 12 + m / 60;
                    hand(h / 12 * 2 * Math.PI, r * 0.5, 5, Theme.windowText);
                    hand(m / 60 * 2 * Math.PI, r * 0.78, 3, Theme.windowText);
                    hand(s / 60 * 2 * Math.PI, r * 0.85, 1, Theme.windowText);
                }
            }
            Field {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 150
                readOnly: true
                input.horizontalAlignment: TextInput.AlignHCenter
                text: Qt.formatTime(clock.date, "h:mm:ss AP")
            }
        }

        Txt {
            anchors.bottom: parent.bottom
            width: parent.width
            elide: Text.ElideRight
            text: "Current time zone: " + (tz.text || "local time")
                + "   ·   Tonight: " + root.moonName(root.moonPhase(clock.date))
        }
    }

    // ---------------------------------------------------------------- Weather
    Column {
        spacing: 8

        Txt {
            visible: Weather.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.danger
            text: Weather.error
        }
        Group {
            title: Weather.place ? "Now in " + Weather.place : "Now"
            width: parent.width
            Row {
                spacing: 14
                Icon { name: Weather.ready ? root.weatherIcon(Weather.current.code, Weather.current.isDay) : "weather-severe-alert"; size: 48 }
                Column {
                    Text {
                        text: Weather.ready ? Math.round(Weather.current.temp) + "°" : Weather.loading ? "…" : "—"
                        color: Theme.text
                        font.family: Theme.fontSerif
                        font.pixelSize: 36
                        font.bold: true
                    }
                    Txt { text: Weather.ready ? Weather.describe(Weather.current.code) : "Getting the weather…" }
                }
                Column {
                    Txt { text: Weather.ready ? "Feels like " + Math.round(Weather.current.feels) + "°" : "" }
                    Txt { text: Weather.ready ? "Humidity " + Weather.current.humidity + "%" : "" }
                    Txt { text: Weather.ready ? "Wind " + Math.round(Weather.current.wind) + " " + Weather.windLabel : "" }
                    Txt { text: Weather.ready ? "Sun " + Qt.formatTime(Weather.sunrise, "h:mm AP") + " – " + Qt.formatTime(Weather.sunset, "h:mm AP") : "" }
                }
            }
        }
        ListBox {
            width: parent.width
            height: 7 * (Theme.menuItem - 2) + Theme.button - 2
            model: Weather.daily
            iconOf: d => root.weatherIcon(d.code, true)
            columns: [
                { title: "Day", width: 120, text: d => d === Weather.daily[0] ? "Today" : Qt.formatDate(d.date, "dddd") },
                { title: "Forecast", width: 0, text: d => Weather.describe(d.code) },
                { title: "Rain", width: 60, text: d => d.pop > 0 ? d.pop + "%" : "" },
                { title: "High", width: 56, text: d => Math.round(d.max) + "°" },
                { title: "Low", width: 56, text: d => Math.round(d.min) + "°" },
            ]
        }
        Row {
            spacing: 12
            // tonight's moon, drawn in 98's two tones
            Canvas {
                id: moon
                width: 52; height: 52
                readonly property real p: root.moonPhase(clock.date)
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const r = 22, cx = 26, cy = 26;
                    ctx.fillStyle = "#202020";
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill();
                    const k = Math.cos(2 * Math.PI * p);
                    const waxing = p < 0.5;
                    ctx.fillStyle = "#ffffc0";
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
                    ctx.save(); ctx.translate(cx, cy); ctx.scale(Math.abs(k), 1);
                    ctx.arc(0, 0, r, Math.PI / 2, -Math.PI / 2, (k > 0) === waxing);
                    ctx.restore();
                    ctx.closePath();
                    ctx.fill();
                    ctx.strokeStyle = Theme.shadow; ctx.lineWidth = 1;
                    ctx.beginPath(); ctx.arc(cx, cy, r + 0.5, 0, 2 * Math.PI); ctx.stroke();
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Txt { text: "Tonight: " + root.moonName(moon.p); bold: true }
                Txt { text: Math.round((1 - Math.cos(2 * Math.PI * moon.p)) / 2 * 100) + "% lit  ·  day " + Math.floor(moon.p * 29.53) + " of 29.5" }
            }
        }
        Row {
            spacing: 8
            Btn { text: "Refresh"; onClicked: Weather.refresh() }
            Txt { height: Theme.button; text: Weather.loading ? "Getting the weather…" : Weather.ready ? "Updated " + Qt.formatTime(Weather.updated, "h:mm AP") : "" }
        }
    }
}
