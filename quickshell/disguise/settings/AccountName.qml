import QtQuick
import Quickshell.Io

// Your full name (from passwd), for the account card.
Item {
    id: root
    property string name: ""
    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1']
        stdout: StdioCollector { onStreamFinished: root.name = text.trim() }
    }
}
