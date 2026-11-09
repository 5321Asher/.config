pragma Singleton

import QtQuick
import Quickshell
import "../theme"

// Weather from Open-Meteo (no API key). Location from Config.weatherCity, or IP lookup.
Singleton {
    id: root

    property string place: ""
    property real lat: NaN
    property real lon: NaN

    property bool loading: false
    property string error: ""
    property date updated
    readonly property bool ready: current !== null

    // { temp, feels, humidity, wind, code, isDay }
    property var current: null
    // [{ time, temp, code, pop, isDay }], next 24 hours
    property var hourly: []
    // [{ date, code, max, min, pop }], 7 days
    property var daily: []
    property date sunrise
    property date sunset

    readonly property string windLabel: ({ kmh: "km/h", mph: "mph", ms: "m/s", kn: "kn" })[Config.windUnit] ?? Config.windUnit

    function refresh() {
        if (loading)
            return;
        loading = true;
        error = "";
        if (isNaN(lat))
            locate();
        else
            fetchForecast();
    }

    function refreshIfStale() {
        if (!ready || Date.now() - updated.getTime() > 10 * 60 * 1000)
            refresh();
    }

    function get(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                fail("Request failed (" + xhr.status + ")");
                return;
            }
            try {
                cb(JSON.parse(xhr.responseText));
            } catch (e) {
                fail("Bad response");
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function fail(msg) {
        error = msg;
        loading = false;
    }

    function locate() {
        if (Config.weatherCity !== "") {
            get("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(Config.weatherCity), data => {
                const r = data.results?.[0];
                if (!r)
                    return fail("City not found");
                place = r.name;
                lat = r.latitude;
                lon = r.longitude;
                fetchForecast();
            });
        } else {
            get("https://ipinfo.io/json", data => {
                const [la, lo] = (data.loc ?? "").split(",").map(parseFloat);
                if (isNaN(la))
                    return fail("Couldn't find location");
                place = data.city ?? "";
                lat = la;
                lon = lo;
                fetchForecast();
            });
        }
    }

    function fetchForecast() {
        const url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&timezone=auto&forecast_days=7"
            + "&temperature_unit=" + Config.tempUnit + "&wind_speed_unit=" + Config.windUnit;

        get(url, data => {
            const c = data.current;
            current = {
                temp: c.temperature_2m,
                feels: c.apparent_temperature,
                humidity: c.relative_humidity_2m,
                wind: c.wind_speed_10m,
                code: c.weather_code,
                isDay: c.is_day === 1
            };

            // Times are local to the location; start from the current hour
            const h = data.hourly;
            const start = Math.max(0, h.time.findIndex(t => t.slice(0, 13) === c.time.slice(0, 13)));
            const hours = [];
            for (let i = start; i < Math.min(start + 24, h.time.length); i++)
                hours.push({
                    time: new Date(h.time[i]),
                    temp: h.temperature_2m[i],
                    code: h.weather_code[i],
                    pop: h.precipitation_probability[i] ?? 0,
                    isDay: h.is_day[i] === 1
                });
            hourly = hours;

            const d = data.daily;
            daily = d.time.map((t, i) => ({
                date: new Date(t + "T12:00"),
                code: d.weather_code[i],
                max: d.temperature_2m_max[i],
                min: d.temperature_2m_min[i],
                pop: d.precipitation_probability_max[i] ?? 0
            }));
            sunrise = new Date(d.sunrise[0]);
            sunset = new Date(d.sunset[0]);

            updated = new Date();
            loading = false;
        });
    }

    // WMO weather code -> text
    function describe(code) {
        if (code === 0) return "Clear";
        if (code === 1) return "Mostly clear";
        if (code === 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code === 45 || code === 48) return "Foggy";
        if (code >= 51 && code <= 55) return "Drizzle";
        if (code === 56 || code === 57) return "Freezing drizzle";
        if (code === 61 || code === 80) return "Light rain";
        if (code === 63 || code === 81) return "Rain";
        if (code === 65 || code === 82) return "Heavy rain";
        if (code === 66 || code === 67) return "Freezing rain";
        if (code >= 71 && code <= 77) return "Snow";
        if (code === 85 || code === 86) return "Snow showers";
        if (code >= 95) return "Thunderstorm";
        return "Unknown";
    }

    // WMO weather code -> Material Design Icons glyph
    function icon(code, isDay = true) {
        let cp;
        if (code <= 1) cp = isDay ? 0xF0599 : 0xF0594;
        else if (code === 2) cp = isDay ? 0xF0595 : 0xF0F31;
        else if (code === 3) cp = 0xF0590;
        else if (code === 45 || code === 48) cp = 0xF0591;
        else if (code === 65 || code === 82) cp = 0xF0596;
        else if (code === 66 || code === 67) cp = 0xF067F;
        else if ((code >= 71 && code <= 77) || code === 85 || code === 86) cp = 0xF0598;
        else if (code >= 95) cp = 0xF067E;
        else cp = 0xF0597;
        return String.fromCodePoint(cp);
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 15 * 60 * 1000
        onTriggered: root.refresh()
    }
}
