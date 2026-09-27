import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Main side panel: header, menus, and notifications in the bottom quarter
Item {
    id: root

    signal closeRequested

    // Switch to a tab by name, e.g. show("Settings", 2)
    function show(name, subPage) {
        const i = tabs.model.findIndex(t => t.name === name);
        if (i >= 0)
            pages.currentIndex = i;
        if (name === "Settings" && subPage !== undefined)
            settingsTab.page = subPage;
    }

    readonly property string user: Quickshell.env("USER") ?? ""
    property string host: ""
    property real uptimeSecs: 0

    property string greeting: ""

    function refresh() {
        const h = new Date().getHours();
        greeting = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
        uptimeFile.reload();
    }

    Component.onCompleted: refresh()

    function fmtUptime(secs) {
        const d = Math.floor(secs / 86400);
        const h = Math.floor(secs % 86400 / 3600);
        const m = Math.floor(secs % 3600 / 60);
        return (d > 0 ? d + "d " : "") + (d > 0 || h > 0 ? h + "h " : "") + m + "m";
    }

    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim()
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptimeSecs = parseFloat(text())
    }

    Timer {
        running: true
        repeat: true
        interval: 60000
        onTriggered: root.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // Header
        Row {
            spacing: 14

            Rectangle {
                width: 52
                height: 52
                radius: 0
                color: Theme.bgDark
                border.width: 1
                border.color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: root.user.charAt(0).toUpperCase()
                    font.family: Theme.font
                    font.pixelSize: 22
                    font.bold: true
                    color: Theme.accent
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: root.greeting + ", " + root.user
                    font.family: Theme.font
                    font.pixelSize: 17
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    text: root.user + "@" + root.host + "  ·  up " + root.fmtUptime(root.uptimeSecs)
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.dim
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.surface
        }

        // Tabs: add an entry here and a matching page in the StackLayout
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: 0
            color: Theme.surface

            RowLayout {
                id: tabBar

                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Repeater {
                    id: tabs

                    model: [
                        { name: "Weather", icon: 0xF0599 },
                        { name: "Stats", icon: 0xF04C5 },
                        { name: "Media", icon: 0xF075A },
                        { name: "Quick", icon: 0xF062E },
                        { name: "Focus", icon: 0xF051F },
                        { name: "Display", icon: 0xF0379 },
                        { name: "Devices", icon: 0xF0079 },
                        { name: "RGB", icon: 0xF03D8 },
                        { name: "Settings", icon: 0xF0493 }
                    ]

                    // Active tab shows its label and takes more room; others are icon-only
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool current: pages.currentIndex === index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: current ? 3 : 1
                        radius: 0
                        color: current ? Theme.bgDark : tabMouse.containsMouse ? Theme.hover : "transparent"
                        border.width: current ? 1 : 0
                        border.color: Theme.accent

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String.fromCodePoint(parent.parent.modelData.icon)
                                font.family: Theme.font
                                font.pixelSize: 15
                                color: parent.parent.current ? Theme.accent : Theme.dim
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: parent.parent.current
                                text: parent.parent.modelData.name
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.accent
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pages.currentIndex = parent.index
                        }
                    }
                }
            }
        }

        StackLayout {
            id: pages

            Layout.fillWidth: true
            Layout.fillHeight: true

            WeatherTab {}
            StatsTab {
                onCloseRequested: root.closeRequested()
            }
            MediaTab {}
            QuickTab {
                onCloseRequested: root.closeRequested()
            }
            FocusTab {}
            DisplayTab {}
            DevicesTab {}
            RgbTab {}
            SettingsTab {
                id: settingsTab
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.surface
        }

        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.height / 4
        }
    }
}
