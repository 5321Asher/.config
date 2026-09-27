import QtQuick
import QtQuick.Layouts

// Tailscale: connection, devices (copy IP, Taildrop) and exit nodes
Item {
    id: root

    // Device being sent a file; shows the file picker when set
    property var sendTarget: null
    property string exitFilter: ""
    property string copied: ""

    readonly property var exitNodes: Net.tsExitNodes.filter(n => {
        const q = exitFilter.trim().toLowerCase();
        return !q || [n.name, n.host, n.country, n.city, n.countryCode].some(s => s.toLowerCase().includes(q));
    })

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    function osIcon(os) {
        os = os.toLowerCase();
        if (os === "windows") return glyph(0xF05B3);
        if (os === "android") return glyph(0xF0032);
        if (os === "macos" || os === "ios") return glyph(0xF0036);
        if (os === "linux") return glyph(0xF033D);
        return glyph(0xF0322);
    }

    function copyIp(ip) {
        Net.copy(ip);
        copied = ip;
        copiedReset.restart();
    }

    Timer {
        id: copiedReset
        interval: 1500
        onTriggered: root.copied = ""
    }

    onVisibleChanged: if (visible) Net.refresh()

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: !root.sendTarget

        ColumnLayout {
            id: content

            width: parent.width
            spacing: 10

            // Connection
            Card {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: root.glyph(0xF0582)
                        font.family: Theme.font
                        font.pixelSize: 20
                        color: Net.tsRunning ? Theme.accent : Theme.dim
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: Net.tsName || "Tailscale"
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.fg
                        }

                        Text {
                            text: Net.tsBusy ? Net.tsBusy + "…"
                                : !Net.tsAvailable ? "Not available"
                                : Net.tsRunning ? Net.tsIp : "Disconnected"
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Net.tsBusy ? Theme.accent : Theme.dim
                        }
                    }

                    IconButton {
                        visible: Net.tsRunning && Net.tsIp !== ""
                        icon: root.glyph(root.copied === Net.tsIp ? 0xF012C : 0xF018F)
                        tint: root.copied === Net.tsIp ? Theme.accent : Theme.fg
                        onClicked: root.copyIp(Net.tsIp)
                    }

                    Switch {
                        enabled: Net.tsAvailable && !Net.tsBusy
                        checked: Net.tsRunning
                        onToggled: Net.toggleTailscale()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Net.tsError !== ""
                text: Net.tsError
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.warn
            }

            // Devices
            Card {
                visible: Net.tsRunning
                title: "Devices"
                trailing: Net.tsPeersOnline + " online"
                trailingColor: Theme.dim
                spacing: 4

                Repeater {
                    model: Net.tsDevices

                    Rectangle {
                        id: dev

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: 0
                        color: devMouse.containsMouse ? Theme.hover : "transparent"

                        MouseArea {
                            id: devMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 12

                            // OS icon with online dot
                            Item {
                                implicitWidth: 22
                                implicitHeight: 22

                                Text {
                                    anchors.centerIn: parent
                                    text: root.osIcon(dev.modelData.os)
                                    font.family: Theme.font
                                    font.pixelSize: 18
                                    color: dev.modelData.online ? Theme.fg : Theme.border
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: -2
                                    width: 9
                                    height: 9
                                    radius: 0
                                    color: dev.modelData.online ? "#9ece6a" : Theme.border
                                    border.width: 2
                                    border.color: Theme.surface
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: dev.modelData.name
                                    elide: Text.ElideRight
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: dev.modelData.online ? Theme.fg : Theme.dim
                                }

                                Text {
                                    text: root.copied === dev.modelData.ip ? "Copied!" : dev.modelData.ip
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    color: root.copied === dev.modelData.ip ? Theme.accent : Theme.dim
                                }
                            }

                            IconButton {
                                icon: root.glyph(root.copied === dev.modelData.ip ? 0xF012C : 0xF018F)
                                tint: root.copied === dev.modelData.ip ? Theme.accent : Theme.fg
                                onClicked: root.copyIp(dev.modelData.ip)
                            }

                            IconButton {
                                icon: root.glyph(0xF048A)
                                enabled: dev.modelData.taildrop
                                onClicked: root.sendTarget = dev.modelData
                            }
                        }
                    }
                }
            }

            // Exit nodes
            Card {
                visible: Net.tsRunning
                title: "Exit node"
                trailing: Net.tsExitNode ? "Active" : "Off"
                trailingColor: Net.tsExitNode ? Theme.accent : Theme.dim
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Allow local network access"
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.fg
                    }

                    Switch {
                        enabled: !Net.tsBusy
                        checked: Net.tsAllowLan
                        onToggled: Net.setAllowLan(!Net.tsAllowLan)
                    }
                }

                TextField {
                    Layout.fillWidth: true
                    visible: Net.tsExitNodes.length > 6
                    placeholder: "Search country or city"
                    icon: root.glyph(0xF0349)
                    onTextChanged: root.exitFilter = text
                }

                ExitRow {
                    name: "None"
                    detail: "Use your own connection"
                    code: ""
                    current: Net.tsExitNode === ""
                    onClicked: Net.setExitNode("")
                }

                Repeater {
                    model: root.exitNodes

                    ExitRow {
                        required property var modelData
                        name: modelData.name
                        detail: modelData.mullvad ? modelData.country + "  ·  Mullvad" : "Your device"
                        code: modelData.countryCode
                        online: modelData.online
                        current: Net.tsExitNode === modelData.ip
                        onClicked: Net.setExitNode(modelData.ip)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: Net.tsExitNodes.length === 0
                    text: "No exit nodes available. Enable the Mullvad add-on (or advertise an exit node) in the Tailscale admin console."
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.border
                }
            }
        }
    }

    // Taildrop file picker
    FilePicker {
        anchors.fill: parent
        visible: !!root.sendTarget
        title: root.sendTarget ? "Send to " + root.sendTarget.name : ""
        onCancelled: root.sendTarget = null
        onPicked: path => {
            Net.sendFile(path, root.sendTarget);
            root.sendTarget = null;
        }
    }

    component ExitRow: Rectangle {
        id: er

        property string name
        property string detail
        property string code
        property bool online: true
        property bool current
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 46
        radius: 0
        opacity: online ? 1 : 0.5
        color: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
             : erMouse.containsMouse ? Theme.hover : "transparent"
        border.width: current ? 1 : 0
        border.color: Theme.accent

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            // Country code badge (no emoji font for flags)
            Rectangle {
                implicitWidth: 30
                implicitHeight: 22
                radius: 0
                color: er.current ? Theme.surface : Theme.hover
                border.width: er.current ? 1 : 0
                border.color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: er.code || root.glyph(er.name === "None" ? 0xF0156 : 0xF01E7)
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.bold: true
                    color: er.current ? Theme.accent : Theme.fg
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: er.name
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    Layout.fillWidth: true
                    text: er.detail
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.dim
                }
            }

            Text {
                visible: er.current
                text: ""
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.accent
            }
        }

        MouseArea {
            id: erMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !er.current && !Net.tsBusy
            onClicked: er.clicked()
        }
    }
}
