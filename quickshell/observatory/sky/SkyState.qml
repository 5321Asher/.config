pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// The live sky's settings and the data every monitor shares.
//   qs ipc call sky toggle | on | off | face <degrees or n/e/s/w>
// Location: Config.skyLatitude/skyLongitude if set, else where Weather located you (IP / city).
Singleton {
    id: root

    property bool enabled: true
    property real azimuth: 180          // the direction the view faces (180 = south)

    readonly property real lat: !isNaN(Config.skyLatitude) ? Config.skyLatitude : Weather.lat
    readonly property real lon: !isNaN(Config.skyLongitude) ? Config.skyLongitude : Weather.lon
    readonly property bool located: !isNaN(lat) && !isNaN(lon)
    readonly property string place: Config.skyPlace !== "" ? Config.skyPlace : Weather.place

    // The catalogue (data/sky.json): stars, named stars, constellation lines and labels
    property var catalogue: null
    FileView {
        path: Quickshell.shellDir + "/data/sky.json"
        onLoaded: { try { root.catalogue = JSON.parse(text()); } catch (e) { console.warn("sky.json:", e); } }
    }

    // Settings survive restarts
    FileView {
        id: saved
        path: Quickshell.statePath("sky.json")
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (s.enabled !== undefined) root.enabled = s.enabled;
                if (s.azimuth !== undefined) root.azimuth = s.azimuth;
            } catch (e) {}
        }
    }
    function save() { saved.setText(JSON.stringify({ enabled: enabled, azimuth: azimuth })); }
    onEnabledChanged: save()
    onAzimuthChanged: save()

    Component.onCompleted: Weather.refreshIfStale()

    IpcHandler {
        target: "sky"

        function toggle(): void { root.enabled = !root.enabled; }
        function on(): void { root.enabled = true; }
        function off(): void { root.enabled = false; }
        function face(dir: string): void {
            const named = { n: 0, north: 0, e: 90, east: 90, s: 180, south: 180, w: 270, west: 270 };
            const v = named[dir.toLowerCase()] ?? parseFloat(dir);
            if (!isNaN(v)) root.azimuth = ((v % 360) + 360) % 360;
        }
    }
}
