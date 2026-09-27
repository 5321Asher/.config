import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell

// Minimal in-panel file browser. Emits picked(path) or cancelled().
Rectangle {
    id: root

    property string title: "Choose a file"
    property string folder: Quickshell.env("HOME")
    readonly property string home: Quickshell.env("HOME")

    signal picked(string path)
    signal cancelled

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    function up() {
        if (folder === "/")
            return;
        folder = folder.replace(/\/[^\/]*$/, "") || "/";
    }

    function size(n) {
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (n >= 1024 && i < units.length - 1) {
            n /= 1024;
            i++;
        }
        return n.toFixed(i === 0 ? 0 : 1) + " " + units[i];
    }

    radius: 0
    color: Theme.bgDark
    border.width: 1
    border.color: Theme.border

    FolderListModel {
        id: files
        folder: "file://" + root.folder
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        sortCaseSensitive: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
                color: Theme.fg
            }

            IconButton {
                icon: root.glyph(0xF0156)
                onClicked: root.cancelled()
            }
        }

        // Quick locations
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { label: "Home", path: "" },
                    { label: "Downloads", path: "/Downloads" },
                    { label: "Documents", path: "/Documents" },
                    { label: "Pictures", path: "/Pictures" },
                    { label: "Videos", path: "/Videos" }
                ]

                IconButton {
                    required property var modelData
                    readonly property string target: root.home + modelData.path
                    label: modelData.label
                    tint: root.folder === target ? Theme.accent : Theme.dim
                    onClicked: root.folder = target
                }
            }
        }

        // Path + up
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                icon: root.glyph(0xF0045)
                enabled: root.folder !== "/"
                onClicked: root.up()
            }

            Text {
                Layout.fillWidth: true
                text: root.folder.startsWith(root.home) ? "~" + root.folder.slice(root.home.length) : root.folder
                elide: Text.ElideLeft
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: files

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "Empty folder"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }

            delegate: Rectangle {
                id: entry

                required property string fileName
                required property string filePath
                required property bool fileIsDir
                required property int fileSize

                width: list.width
                height: 36
                radius: 0
                color: entryMouse.containsMouse ? Theme.hover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: root.glyph(entry.fileIsDir ? 0xF024B : 0xF0214)
                        font.family: Theme.font
                        font.pixelSize: 15
                        color: entry.fileIsDir ? Theme.accent : Theme.dim
                    }

                    Text {
                        Layout.fillWidth: true
                        text: entry.fileName
                        elide: Text.ElideMiddle
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.fg
                    }

                    Text {
                        visible: !entry.fileIsDir
                        text: root.size(entry.fileSize)
                        font.family: Theme.font
                        font.pixelSize: 10
                        color: Theme.dim
                    }
                }

                MouseArea {
                    id: entryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entry.fileIsDir ? root.folder = entry.filePath : root.picked(entry.filePath)
                }
            }
        }
    }
}
