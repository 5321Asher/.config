import QtQuick
import QtQuick.Layouts

// OpenRGB: pick a color, apply to everything or per device, pick effect modes, load/save profiles
Flickable {
    id: root

    property real hue: 0.62
    property real sat: 0.5
    property real val: 0.97
    readonly property color picked: Qt.hsva(hue, sat, val, 1)

    readonly property var swatches: [Theme.accent, Theme.purple, "#7dcfff", Theme.green, Theme.warn, "#ff9e64", Theme.danger, "#ffffff"]

    function glyph(cp) {
        return String.fromCodePoint(cp);
    }

    // Keep the hex field in sync without binding it (typing would break a binding)
    onPickedChanged: hexField.text = Rgb.hex(picked)

    function setColor(c) {
        c = Qt.color(c);
        hue = Math.max(0, c.hsvHue);
        sat = c.hsvSaturation;
        val = c.hsvValue;
    }

    function typeIcon(type) {
        type = type.toLowerCase();
        if (type === "gpu") return glyph(0xF08AE);
        if (type === "motherboard") return glyph(0xF0697);
        if (type === "keyboard") return glyph(0xF030C);
        if (type === "mouse") return glyph(0xF037D);
        if (type.includes("led")) return glyph(0xF07D6);
        return glyph(0xF0335);
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    onVisibleChanged: if (visible && !Rgb.scanned) Rgb.scan()
    Component.onCompleted: if (visible && !Rgb.scanned) Rgb.scan()

    ColumnLayout {
        id: content

        width: root.width
        spacing: 10

        Text {
            Layout.fillWidth: true
            visible: Rgb.scanned && !Rgb.available
            text: "OpenRGB isn't installed"
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.dim
        }

        // Color
        Card {
            visible: Rgb.available || !Rgb.scanned
            title: "Color"
            trailing: Rgb.busy ? "Working…" : Rgb.devices.length + " devices"
            trailingColor: Rgb.busy ? Theme.accent : Theme.dim
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Preview with a soft glow
                Rectangle {
                    implicitWidth: 64
                    implicitHeight: 64
                    radius: 0
                    color: root.picked
                    border.width: 2
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 14
                        height: parent.height + 14
                        radius: 0
                        color: "transparent"
                        border.width: 5
                        border.color: Qt.rgba(root.picked.r, root.picked.g, root.picked.b, 0.25)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    TextField {
                        id: hexField
                        Layout.fillWidth: true
                        icon: "#"
                        placeholder: "RRGGBB"
                        Component.onCompleted: text = Rgb.hex(root.picked)
                        onAccepted: if (/^[0-9a-fA-F]{6}$/.test(text)) root.setColor("#" + text)
                    }

                    // Swatches
                    Row {
                        spacing: 6

                        Repeater {
                            model: root.swatches

                            Rectangle {
                                required property color modelData
                                width: 22
                                height: 22
                                radius: 0
                                color: modelData
                                border.width: swMouse.containsMouse ? 2 : 0
                                border.color: Theme.fg

                                MouseArea {
                                    id: swMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setColor(parent.modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Hue
            GradientSlider {
                value: root.hue
                knobColor: Qt.hsva(root.hue, 1, 1, 1)
                stops: [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1].map(h => Qt.hsva(h === 1 ? 0.999 : h, 1, 1, 1))
                onMoved: v => root.hue = Math.min(0.999, v)
            }

            // Saturation
            GradientSlider {
                value: root.sat
                knobColor: root.picked
                stops: [Qt.hsva(root.hue, 0, root.val, 1), Qt.hsva(root.hue, 1, root.val, 1)]
                onMoved: v => root.sat = v
            }

            // Brightness
            GradientSlider {
                value: root.val
                knobColor: root.picked
                stops: ["#000000", Qt.hsva(root.hue, root.sat, 1, 1)]
                onMoved: v => root.val = v
            }

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Match theme"
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.fg
                    }

                    Text {
                        text: "Recolour every device when the colour theme changes"
                        font.family: Theme.font
                        font.pixelSize: 10
                        color: Theme.dim
                    }
                }

                Switch {
                    checked: Rgb.followWallpaper
                    onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconButton {
                    icon: root.glyph(0xF0336)
                    label: "Off"
                    enabled: !Rgb.busy
                    onClicked: Rgb.setAll("#000000")
                }

                Item { Layout.fillWidth: true }

                IconButton {
                    icon: root.glyph(0xF0450)
                    enabled: !Rgb.busy
                    spinning: Rgb.busy
                    onClicked: Rgb.scan()
                }

                IconButton {
                    primary: true
                    icon: root.glyph(0xF03D8)
                    label: "Apply to all"
                    enabled: !Rgb.busy && Rgb.devices.length > 0
                    onClicked: Rgb.setAll(root.picked)
                }
            }

            Text {
                Layout.fillWidth: true
                visible: Rgb.error !== ""
                text: Rgb.error
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.danger
            }
        }

        // Profiles
        Card {
            visible: Rgb.available
            title: "Profiles"
            spacing: 8

            Flow {
                Layout.fillWidth: true
                visible: Rgb.profiles.length > 0
                spacing: 6

                Repeater {
                    model: Rgb.profiles

                    IconButton {
                        required property string modelData
                        icon: root.glyph(0xF0E38)
                        label: modelData
                        enabled: !Rgb.busy
                        onClicked: Rgb.loadProfile(modelData)
                    }
                }
            }

            Text {
                visible: Rgb.profiles.length === 0
                text: "No saved profiles yet"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    id: profileName
                    Layout.fillWidth: true
                    placeholder: "Save current lighting as…"
                    onAccepted: if (text.trim()) { Rgb.saveProfile(text.trim()); text = ""; }
                }

                IconButton {
                    label: "Save"
                    enabled: !Rgb.busy && profileName.text.trim() !== ""
                    onClicked: {
                        Rgb.saveProfile(profileName.text.trim());
                        profileName.text = "";
                    }
                }
            }
        }

        // Devices
        Card {
            visible: Rgb.available
            title: "Devices"
            spacing: 14

            Repeater {
                model: Rgb.devices

                ColumnLayout {
                    id: dev

                    required property var modelData
                    property string mode: modelData.mode

                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 0
                            color: Theme.hover

                            Text {
                                anchors.centerIn: parent
                                text: root.typeIcon(dev.modelData.type)
                                font.family: Theme.font
                                font.pixelSize: 16
                                color: Theme.fg
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
                                color: Theme.fg
                            }

                            Text {
                                text: dev.modelData.type + (dev.modelData.mode ? "  ·  " + dev.modelData.mode : "")
                                font.family: Theme.font
                                font.pixelSize: 10
                                color: Theme.dim
                            }
                        }

                        IconButton {
                            label: "Apply"
                            enabled: !Rgb.busy
                            onClicked: Rgb.setDevice(dev.modelData, dev.mode, root.picked)
                        }
                    }

                    Dropdown {
                        visible: dev.modelData.modes.length > 1
                        options: dev.modelData.modes.map(m => ({ label: m, value: m }))
                        value: dev.mode
                        onPicked: v => dev.mode = v
                    }

                    // Addressable headers (fans, strips): LED count per zone
                    Repeater {
                        model: Rgb.resizableZones(dev.modelData)

                        RowLayout {
                            id: zone

                            required property var modelData
                            property int leds: modelData.leds

                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: zone.modelData.name + (zone.modelData.leds === 0 ? "  ·  not set up" : "")
                                elide: Text.ElideRight
                                font.family: Theme.font
                                font.pixelSize: 11
                                color: zone.modelData.leds === 0 ? Theme.warn : Theme.dim
                            }

                            IconButton {
                                icon: root.glyph(0xF0374)
                                onClicked: zone.leds = Math.max(zone.modelData.min, zone.leds - 1)
                            }

                            Text {
                                Layout.preferredWidth: 58
                                horizontalAlignment: Text.AlignHCenter
                                text: zone.leds + " LEDs"
                                font.family: Theme.font
                                font.pixelSize: 11
                                font.bold: true
                                color: zone.leds !== zone.modelData.leds ? Theme.accent : Theme.fg
                            }

                            IconButton {
                                icon: root.glyph(0xF0415)
                                onClicked: zone.leds = Math.min(zone.modelData.max, zone.leds + 1)
                            }

                            IconButton {
                                label: "Set"
                                primary: zone.leds !== zone.modelData.leds
                                enabled: !Rgb.busy
                                onClicked: Rgb.setZoneSize(dev.modelData, zone.modelData.index, zone.leds)
                            }
                        }
                    }
                }
            }
        }
    }

    // Slider over a horizontal gradient (hue / saturation / brightness)
    component GradientSlider: Item {
        id: gs

        property real value
        property var stops: []
        property color knobColor
        signal moved(real value)

        Layout.fillWidth: true
        implicitHeight: 22

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 12
            radius: 0
            gradient: Gradient {
                id: grad
                orientation: Gradient.Horizontal
            }

            Component.onCompleted: gs.rebuild()
        }

        function rebuild() {
            for (const old of grad.stops)
                old.destroy();
            const list = [];
            for (let i = 0; i < stops.length; i++)
                list.push(stopComponent.createObject(grad, { position: stops.length > 1 ? i / (stops.length - 1) : 0, color: stops[i] }));
            grad.stops = list;
        }

        onStopsChanged: rebuild()

        Component {
            id: stopComponent
            GradientStop {}
        }

        Rectangle {
            x: gs.value * (gs.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 0
            color: gs.knobColor
            border.width: 3
            border.color: Theme.fg
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function set(x) {
                gs.moved(Math.max(0, Math.min(1, x / width)));
            }
            onPressed: e => set(e.x)
            onPositionChanged: e => { if (pressed) set(e.x); }
        }
    }
}
