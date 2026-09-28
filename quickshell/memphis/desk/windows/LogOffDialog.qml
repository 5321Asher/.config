import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// "Log Off Memphis": are you sure? Yes runs the shared Power menu's log-out entry.
Win {
    id: root

    title: "Log Off Memphis"

    function yes() {
        root.closeRequested();
        Elephant.query("menus:power", l => {
            const e = l.find(x => /log ?out|log ?off/i.test(x.text ?? ""));
            if (e) Elephant.activate(e);
        });
    }
    Component.onCompleted: yesBtn.forceActiveFocus()
    Keys.onReturnPressed: yes()

    Item {
        anchors.fill: parent
        anchors.margins: Theme.pad + 4
        Icon { id: pic; name: "system-log-out"; size: 40 }
        Txt {
            x: pic.width + Theme.pad + 4
            height: 40
            text: "Are you sure you want to log off?"
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 8
            Btn { id: yesBtn; text: "Yes"; isDefault: true; onClicked: root.yes() }
            Btn { text: "No"; onClicked: root.closeRequested() }
        }
    }
}
