import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Time & language: the time now (big), time zone, then the weather (now and the week) and the moon.
Column {
    id: root
    spacing: 4
    Component.onCompleted: Weather.refreshIfStale()
    SystemClock { id: clock; precision: SystemClock.Seconds }
    property string tz: ""
    Process {
        running: true
        command: ["sh", "-c", "readlink /etc/localtime | sed 's|.*zoneinfo/||'"]
        stdout: StdioCollector { onStreamFinished: root.tz = text.trim().replace(/_/g, " ") }
    }
    function weatherName(c) {
        if (c <= 1) return "weather-clear"; if (c === 2) return "weather-few-clouds"; if (c === 3) return "weather-overcast";
        if (c === 45 || c === 48) return "weather-fog"; if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "weather-snow";
        if (c >= 95) return "weather-storm"; return "weather-showers";
    }
    function moonPhase(t) { const p = ((t.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000 / 29.530588853) % 1; return p < 0 ? p + 1 : p; }
    function moonName(p) { return ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"][Math.round(p * 8) % 8]; }

    Card {
        width: parent.width
        height: 110
        Column {
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: Qt.formatTime(clock.date, "h:mm:ss AP"); size: Theme.titleLarge; strong: true }
            Txt { text: Qt.formatDate(clock.date, "dddd, MMMM d, yyyy"); level: 2 }
        }
    }
    SettingRow { width: parent.width; glyph: ""; title: "Time zone"; subtitle: "Set automatically by the system"; Txt { height: 32; text: root.tz || "Local time"; level: 2 } }
    SettingRow {
        id: moonRow
        readonly property real p: root.moonPhase(clock.date)
        width: parent.width; glyph: "\ue708"; title: "Tonight's moon"
        subtitle: Math.round((1 - Math.cos(2 * Math.PI * p)) / 2 * 100) + "% lit"
        Txt { height: 32; text: root.moonName(moonRow.p); level: 2 }
    }

    Header { text: Weather.place ? "Weather in " + Weather.place : "Weather" }
    Card {
        width: parent.width
        height: 120
        WeatherIcon { x: 24; anchors.verticalCenter: parent.verticalCenter; size: 64; code: Weather.current?.code ?? 2; day: Weather.current?.isDay ?? true }
        Column {
            x: 110
            anchors.verticalCenter: parent.verticalCenter
            Txt { text: Weather.ready ? Math.round(Weather.current.temp) + "° · " + Weather.describe(Weather.current.code) : (Weather.error || "Getting the weather…"); size: Theme.subtitle; strong: true }
            Txt { text: Weather.ready ? "Feels like " + Math.round(Weather.current.feels) + "° · Humidity " + Weather.current.humidity + "% · Wind " + Math.round(Weather.current.wind) + " " + Weather.windLabel : ""; level: 2 }
            Txt { text: Weather.ready ? "Sunrise " + Qt.formatTime(Weather.sunrise, "h:mm AP") + " · Sunset " + Qt.formatTime(Weather.sunset, "h:mm AP") : ""; level: 2; size: Theme.caption }
        }
        Btn { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; kind: "subtle"; glyph: ""; width: 36; onClicked: Weather.refresh() }
    }
    Repeater {
        model: Weather.daily
        SettingRow {
            required property var modelData
            required property int index
            width: root.width
            icon: root.weatherName(modelData.code)
            title: index === 0 ? "Today" : Qt.formatDate(modelData.date, "dddd")
            subtitle: Weather.describe(modelData.code) + (modelData.pop > 0 ? " · " + modelData.pop + "% rain" : "")
            Txt { height: 32; text: Math.round(modelData.max) + "° / " + Math.round(modelData.min) + "°" }
        }
    }
}
