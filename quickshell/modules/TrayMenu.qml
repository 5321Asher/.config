import QtQuick
import QtQuick.Layouts
import Quickshell

// Themed tray menu. Submenus open in place with a back row.
ColumnLayout {
    id: root

    property var menu: null
    property string title
    // Submenu handles, innermost last
    property var stack: []

    signal done

    readonly property var current: stack.length ? stack[stack.length - 1] : menu

    onMenuChanged: stack = []

    width: 240
    spacing: 2

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Text {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        visible: root.title !== "" && root.stack.length === 0
        text: root.title
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 2
        font.capitalization: Font.AllUppercase
        color: Theme.dim
    }

    // Back out of a submenu
    Entry {
        visible: root.stack.length > 0
        text: "Back"
        glyph: String.fromCodePoint(0xF0141)
        onClicked: root.stack = root.stack.slice(0, -1)
    }

    Repeater {
        model: opener.children

        Loader {
            id: loader

            required property var modelData

            Layout.fillWidth: true
            sourceComponent: modelData.isSeparator ? separator : entry

            Component {
                id: separator

                Rectangle {
                    implicitHeight: 9
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.hover
                    }
                }
            }

            Component {
                id: entry

                Entry {
                    readonly property var e: loader.modelData
                    text: e.text.replace(/_(?=\S)/, "")
                    iconSource: e.icon
                    enabled: e.enabled
                    check: e.buttonType === QsMenuButtonType.CheckBox ? (e.checkState === Qt.Checked ? "on" : "off")
                         : e.buttonType === QsMenuButtonType.RadioButton ? (e.checkState === Qt.Checked ? "radio-on" : "radio-off")
                         : ""
                    submenu: e.hasChildren
                    onClicked: {
                        if (e.hasChildren) {
                            root.stack = root.stack.concat([e]);
                        } else {
                            e.triggered();
                            root.done();
                        }
                    }
                }
            }
        }
    }

    component Entry: Rectangle {
        id: en

        property string text
        property string glyph
        property string iconSource
        property string check
        property bool submenu
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 32
        radius: 0
        opacity: enabled ? 1 : 0.4
        color: enMouse.containsMouse && enabled ? Theme.hover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            // Check / radio state, icon, or glyph (space kept so labels line up)
            Item {
                implicitWidth: 16
                implicitHeight: 16

                Text {
                    anchors.centerIn: parent
                    visible: en.check !== "" || en.glyph !== ""
                    text: en.glyph !== "" ? en.glyph
                        : String.fromCodePoint({ "on": 0xF0C52, "off": 0xF0131, "radio-on": 0xF043E, "radio-off": 0xF043D }[en.check] ?? 0x20)
                    font.family: Theme.font
                    font.pixelSize: 14
                    color: en.check === "on" || en.check === "radio-on" ? Theme.accent : Theme.dim
                }

                Image {
                    anchors.fill: parent
                    visible: en.check === "" && en.glyph === "" && en.iconSource !== ""
                    source: en.iconSource
                    sourceSize.width: 16
                    sourceSize.height: 16
                }
            }

            Text {
                Layout.fillWidth: true
                text: en.text
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.fg
            }

            Text {
                visible: en.submenu
                text: String.fromCodePoint(0xF0142)
                font.family: Theme.font
                font.pixelSize: 14
                color: Theme.dim
            }
        }

        MouseArea {
            id: enMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: en.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (en.enabled) en.clicked()
        }
    }
}
