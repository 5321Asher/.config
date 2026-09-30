import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// "Monitor Settings": after Display Properties applies a new screen layout, keep it? No (or the
// countdown running out, or closing this) puts the old one back. Its own window, as in 98, so it
// stays up when Display Properties is closed with OK. Desk opens it while Displays.confirming.
Win {
    id: root

    title: "Monitor Settings"
    closable: true
    onCloseRequested: if (Displays.confirming) Displays.revert()

    Component.onCompleted: yesBtn.forceActiveFocus()
    Keys.onReturnPressed: Displays.keep()

    Item {
        anchors.fill: parent
        anchors.margins: Theme.pad + 4
        Icon { id: pic; name: "dialog-question"; size: 40 }
        Txt {
            x: pic.width + Theme.pad + 4
            width: parent.width - x
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignTop
            text: "Your desktop has been reconfigured. Do you want to keep these settings?\n\nReverting in "
                + Displays.countdown + (Displays.countdown === 1 ? " second." : " seconds.")
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 8
            Btn { id: yesBtn; text: "Yes"; isDefault: true; onClicked: Displays.keep() }
            Btn { text: "No"; onClicked: Displays.revert() }
        }
    }
}
