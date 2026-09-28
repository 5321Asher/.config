import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// "Shut Down Windows": the computer-and-moon picture, "What do you want the computer to do?" and a
// radio button per choice. The choices are the shared Power menu's entries (~/.config/elephant/
// menus/power.toml, the same ones Walker shows), in 98's words where there is one. OK runs it.
Win {
    id: root

    title: "Shut Down Memphis"
    helpButton: true
    onHelpRequested: Desk.show("help")

    property var entries: []
    property int choice: 0

    // 98's wording for the shared entries
    function words(t) {
        const s = t.toLowerCase();
        if (s.includes("lock")) return "Lock the computer";
        if (s.includes("suspend") || s.includes("sleep")) return "Stand by";
        if (s.includes("logout") || s.includes("log out")) return "Log off and log on as a different user";
        if (s.includes("reboot") || s.includes("restart")) return "Restart";
        if (s.includes("shutdown") || s.includes("shut down") || s.includes("poweroff")) return "Shut down";
        return t;
    }

    Component.onCompleted: Elephant.query("menus:power", l => {
        root.entries = l;
        const i = l.findIndex(e => /shut ?down|poweroff/i.test(e.text ?? ""));
        root.choice = i >= 0 ? i : 0;
        options.forceActiveFocus();
    })
    Keys.onUpPressed: choice = Math.max(0, choice - 1)
    Keys.onDownPressed: choice = Math.min(entries.length - 1, choice + 1)
    Keys.onReturnPressed: go()

    function go() {
        const e = entries[choice];
        root.closeRequested();
        if (e) Elephant.activate(e);
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.pad + 4

        Icon {
            id: pic
            name: "system-shutdown"
            size: 48
        }
        Column {
            id: options
            x: pic.width + Theme.pad + 8
            width: parent.width - x
            spacing: 6
            focus: true
            Txt { text: "What do you want the computer to do?"; height: 26 }
            Repeater {
                model: root.entries
                Check {
                    required property var modelData
                    required property int index
                    radio: true
                    text: root.words(modelData.text ?? "")
                    checked: root.choice === index
                    onToggled: root.choice = index
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 8
            Btn { text: "OK"; isDefault: true; onClicked: root.go() }
            Btn { text: "Cancel"; onClicked: root.closeRequested() }
            Btn { text: "Help"; onClicked: Desk.show("help") }
        }
    }
}
