pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// CPU load, memory use and CPU temperature, for the instrument cluster.
// One small sh loop reads /proc/stat, /proc/meminfo and the k10temp sensor every
// Theme.sysInterval ms and prints them as one line; nothing is polled faster than that.
Singleton {
    id: root

    property real cpu: 0        // 0-1, busy share since the last sample
    property real mem: 0        // 0-1, (total - available) / total
    property real temp: 0       // °C, 0 when there's no sensor
    property bool hasTemp: false

    property var last: null     // previous /proc/stat totals

    Process {
        running: true
        // hwmon numbers change between boots: find the CPU sensor by name (AMD k10temp, Intel coretemp)
        command: ["sh", "-c", `
            t=""
            for d in /sys/class/hwmon/hwmon*; do
                case "$(cat "$d/name" 2>/dev/null)" in k10temp|coretemp|zenpower) t="$d/temp1_input"; break ;; esac
            done
            while :; do
                set -- $(head -1 /proc/stat)
                mt=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
                ma=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
                tv=$( [ -n "$t" ] && cat "$t" 2>/dev/null || echo -1)
                echo "$2 $3 $4 $5 $6 $7 $8 $9 $mt $ma $tv"
                sleep ${Theme.sysInterval / 1000}
            done`]
        stdout: SplitParser {
            onRead: line => {
                const v = line.trim().split(/\s+/).map(Number);
                if (v.length < 11) return;
                // user nice system idle iowait irq softirq steal
                const idle = v[3] + v[4];
                const total = v.slice(0, 8).reduce((a, b) => a + b, 0);
                if (root.last) {
                    const dt = total - root.last.total, di = idle - root.last.idle;
                    if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
                }
                root.last = { total: total, idle: idle };
                if (v[8] > 0) root.mem = (v[8] - v[9]) / v[8];
                root.hasTemp = v[10] >= 0;
                if (root.hasTemp) root.temp = v[10] / 1000;
            }
        }
    }
}
