import QtQuick
import Quickshell
import Quickshell.Widgets

// A theme icon (Win11 while Disguise is active) by name, a file path, or an image:// url.
IconImage {
    property string name: ""
    property string fallback: "application-x-executable"
    property int size: 24

    implicitSize: size
    asynchronous: true
    source: {
        const n = name;
        if (!n) return Quickshell.iconPath(fallback);
        if (n.startsWith("/")) return "file://" + n;
        if (n.includes("://")) return n;
        return Quickshell.iconPath(n, fallback);
    }
}
