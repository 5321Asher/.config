pragma Singleton

import QtQuick
import Quickshell

// User settings
Singleton {
    // Workspaces shown in the bar and the overview
    readonly property int workspaceCount: 5
    // City name for weather, e.g. "Toronto". Empty = locate by IP address.
    readonly property string weatherCity: ""
    // "celsius" or "fahrenheit"
    readonly property string tempUnit: "celsius"
    // "kmh", "mph", "ms" or "kn"
    readonly property string windUnit: "kmh"
}
