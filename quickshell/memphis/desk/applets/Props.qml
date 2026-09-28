import QtQuick
import "../../theme"
import "../../widgets"
import ".."

// A Properties sheet ("Display Properties", "Network Properties"…): a dialog with a ? and a close
// button, a tab control filling it, and OK / Cancel / Apply along the bottom. Changes here take
// effect at once, so OK and Cancel both just close and Apply stays grey (unless a page sets
// `applyEnabled` and handles applied()). `tab` (from Desk) selects a page by name.
Win {
    id: root

    property var tabs: []
    property string tab: ""
    property bool applyEnabled: false
    default property alias pages: tabView.pages
    readonly property int current: tabView.current

    signal applied()

    helpButton: true
    onHelpRequested: Desk.show("help")

    onTabChanged: {
        const i = tabs.indexOf(tab);
        if (i >= 0) tabView.current = i;
    }
    Component.onCompleted: {
        const i = tabs.indexOf(tab);
        if (i >= 0) tabView.current = i;
    }

    Tabs {
        id: tabView
        x: 6
        y: 8
        width: parent.width - 12
        height: parent.height - 8 - Theme.button - 16
        tabs: root.tabs
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 6
        y: parent.height - Theme.button - 7
        spacing: 6
        Btn { text: "OK"; isDefault: true; onClicked: { if (root.applyEnabled) root.applied(); root.closeRequested(); } }
        Btn { text: "Cancel"; onClicked: root.closeRequested() }
        Btn { text: "Apply"; enabled: root.applyEnabled; onClicked: root.applied() }
    }
}
