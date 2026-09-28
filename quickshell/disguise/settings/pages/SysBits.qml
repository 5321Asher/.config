import QtQuick
import Quickshell.Io

// This machine's names and numbers for About and Home: host, model, OS, kernel, uptime, user.
Item {
    id: root
    property string host: ""
    property string model: ""
    property string os: ""
    property string kernel: ""
    property string fullName: ""
    property string user: ""
    property int up: 0
    property string installed: ""
    Process {
        running: true
        command: ["sh", "-c", 'uname -n; cat /sys/class/dmi/id/product_name 2>/dev/null || echo; . /etc/os-release; echo "$PRETTY_NAME"; uname -r; getent passwd "$USER" | cut -d: -f5 | cut -d, -f1; echo "$USER"; cut -d. -f1 /proc/uptime; stat -c %w / 2>/dev/null | cut -d" " -f1']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.host = l[0] ?? ""; root.model = (l[1] ?? "").trim(); root.os = l[2] ?? ""; root.kernel = l[3] ?? "";
                root.fullName = l[4] ?? ""; root.user = l[5] ?? ""; root.up = parseInt(l[6]) || 0; root.installed = l[7] ?? "";
            }
        }
    }
    function uptime() {
        const s = up, d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + (d > 1 ? " days, " : " day, ") : "") + h + " hr " + m + " min";
    }
}
