pragma Singleton

import QtQuick
import Quickshell

// User settings (the same ones Sharp has)
Singleton {
    // City name for weather, e.g. "Toronto". Empty = locate by IP address.
    readonly property string weatherCity: ""
    // "celsius" or "fahrenheit"
    readonly property string tempUnit: "celsius"
    // "kmh", "mph", "ms" or "kn"
    readonly property string windUnit: "kmh"
    // The live sky's location. NaN = use the weather's location (weatherCity, or IP lookup).
    readonly property real skyLatitude: NaN
    readonly property real skyLongitude: NaN
    readonly property string skyPlace: ""
}
