import QtQuick
import Quickshell
import "../theme"
import "../services"

// 4 · Instrument cluster: CPU load, memory and CPU temperature as three analog gauges.
// Click any of them for btop.
Row {
    id: root

    spacing: Theme.gaugeSpacing
    layoutDirection: Qt.RightToLeft

    function monitor() { Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"]); }

    Gauge {
        visible: SysInfo.hasTemp
        label: "temp"
        value: (SysInfo.temp - Theme.tempMin) / (Theme.tempMax - Theme.tempMin)
        readout: Math.round(SysInfo.temp) + "°C"
        onClicked: root.monitor()
    }
    Gauge {
        label: "mem"
        value: SysInfo.mem
        readout: Math.round(SysInfo.mem * 100) + "%"
        onClicked: root.monitor()
    }
    Gauge {
        label: "cpu"
        value: SysInfo.cpu
        readout: Math.round(SysInfo.cpu * 100) + "%"
        onClicked: root.monitor()
    }
}
