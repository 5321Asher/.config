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
}
