import QtQuick
import QtQuick.Layouts

// Wi-Fi: power, current connection, and every network in range
Flickable {
    id: root

    // SSID of the row that's expanded (password / actions)
    property string expanded: ""

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    function signalIcon(net) {
        const level = net.signal >= 75 ? 3 : net.signal >= 50 ? 2 : net.signal >= 25 ? 1 : 0;
        return glyph((net.secure ? [0xF0920, 0xF0923, 0xF0926, 0xF0929] : [0xF091F, 0xF0922, 0xF0925, 0xF0928])[level]);
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    onVisibleChanged: if (visible && Net.wifiEnabled && Net.networks.length === 0) Net.scan()
    Component.onCompleted: if (Net.wifiEnabled) Net.scan()

    ColumnLayout {
        id: content

        width: root.width
        spacing: 10

        // Power + rescan
        Card {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: root.glyph(Net.wifiEnabled ? 0xF05A9 : 0xF05AA)
                    font.family: Theme.font
                    font.pixelSize: 20
                    color: Net.wifiEnabled ? Theme.accent : Theme.dim
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: "Wi-Fi"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.fg
                    }

                    Text {
                        text: !Net.wifiEnabled ? "Off" : Net.ssid ? "Connected to " + Net.ssid : "Not connected"
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.dim
                    }
                }

                IconButton {
                    visible: Net.wifiEnabled
                    icon: root.glyph(0xF0450)
                    spinning: Net.scanning
                    enabled: !Net.scanning
                    onClicked: Net.scan()
                }

                Switch {
                    checked: Net.wifiEnabled
                    onToggled: {
                        Net.toggleWifi();
                        if (Net.wifiEnabled)
                            Qt.callLater(Net.scan);
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: Net.wifiError !== ""
            text: Net.wifiError
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.danger
        }

        // Networks
        Card {
            visible: Net.wifiEnabled
            title: "Networks"
            trailing: Net.scanning ? "Scanning…" : Net.networks.length + " found"
            trailingColor: Theme.dim
            spacing: 4

            Text {
                visible: !Net.scanning && Net.networks.length === 0
                text: "No networks in range"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }

            Repeater {
                model: Net.networks

                Rectangle {
                    id: row

                    required property var modelData
                    readonly property var net: modelData
                    readonly property bool open: root.expanded === net.ssid
                    readonly property bool busy: Net.connecting === net.ssid

                    Layout.fillWidth: true
                    implicitHeight: rowCol.implicitHeight + 16
                    radius: 0
                    color: net.inUse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                         : open || rowMouse.containsMouse ? Theme.hover : "transparent"
                    border.width: net.inUse ? 1 : 0
                    border.color: Theme.accent

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.expanded = row.open ? "" : row.net.ssid;
                            Net.wifiError = "";
                            if (root.expanded && row.net.secure && !row.net.saved && !row.net.inUse)
                                Qt.callLater(() => password.focusInput());
                        }
                    }

                    ColumnLayout {
                        id: rowCol

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: root.signalIcon(row.net)
                                font.family: Theme.font
                                font.pixelSize: 17
                                color: row.net.inUse ? Theme.accent : Theme.fg
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: row.net.ssid
                                    elide: Text.ElideRight
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.fg
                                }

                                Text {
                                    text: row.busy ? "Connecting…"
                                        : [row.net.inUse ? "Connected" : row.net.saved ? "Saved" : "",
                                           row.net.security || "Open",
                                           row.net.signal + "%"].filter(s => s).join("  ·  ")
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    color: row.busy ? Theme.accent : Theme.dim
                                }
                            }

                            Text {
                                text: root.glyph(row.open ? 0xF0143 : 0xF0140)
                                font.family: Theme.font
                                font.pixelSize: 14
                                color: Theme.dim
                            }
                        }

                        // Expanded: password and actions
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: row.open
                            spacing: 8

                            TextField {
                                id: password
                                Layout.fillWidth: true
                                visible: row.net.secure && !row.net.saved && !row.net.inUse
                                placeholder: "Password"
                                icon: root.glyph(0xF033E)
                                password: true
                                onAccepted: Net.connect(row.net, text)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Item { Layout.fillWidth: true }

                                IconButton {
                                    visible: row.net.saved !== ""
                                    icon: root.glyph(0xF01B4)
                                    label: "Forget"
                                    tint: Theme.danger
                                    onClicked: {
                                        Net.forget(row.net);
                                        root.expanded = "";
                                    }
                                }

                                IconButton {
                                    visible: row.net.inUse
                                    label: "Disconnect"
                                    onClicked: Net.disconnectWifi()
                                }

                                IconButton {
                                    visible: !row.net.inUse
                                    primary: true
                                    label: row.busy ? "Connecting…" : "Connect"
                                    enabled: !row.busy && (!password.visible || password.text.length >= 8)
                                    onClicked: Net.connect(row.net, password.visible ? password.text : "")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
