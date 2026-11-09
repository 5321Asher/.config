pragma Singleton

import QtQuick
import Quickshell

// Which screens show their home (an empty workspace): the system stats only run while one does
// (or a panel that shows them is open).
Singleton {
    id: root

    property var screens: ({})
    readonly property bool any: Object.values(screens).some(v => v)

    function set(name, on) {
        if ((screens[name] ?? false) === on) return;
        const c = Object.assign({}, screens);
        c[name] = on;
        screens = c;
    }
}
