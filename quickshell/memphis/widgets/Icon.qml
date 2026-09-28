import QtQuick
import Quickshell
import Quickshell.Widgets

// A theme icon (Chicago95 while Memphis is active) by name, a file path, or an image:// url.
// `fallback` is used when the theme has no icon of that name.
IconImage {
    id: root

    property string name: ""
    property string fallback: "application-x-executable"
    property int size: 20

    implicitSize: size
    asynchronous: true
    source: {
        const n = name;
        if (!n) return "";
        if (n.startsWith("/")) return "file://" + n;
        if (n.includes("://")) return n;
        return Quickshell.iconPath(n, fallback);
    }
}
