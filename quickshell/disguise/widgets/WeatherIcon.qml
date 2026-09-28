import QtQuick
import "../theme"

// The weather as an icon from the theme (Win11's are drawn in colour), by WMO code.
AppIcon {
    property int code: 0
    property bool day: true
    fallback: "weather-few-clouds"
    name: {
        const c = code;
        if (c <= 1) return day ? "weather-clear" : "weather-clear-night";
        if (c === 2) return day ? "weather-few-clouds" : "weather-few-clouds-night";
        if (c === 3) return "weather-overcast";
        if (c === 45 || c === 48) return "weather-fog";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "weather-snow";
        if (c >= 95) return "weather-storm";
        if (c >= 51 && c <= 57) return "weather-showers-scattered";
        return "weather-showers";
    }
}
