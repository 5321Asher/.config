import QtQuick
import QtQuick.Effects
import Quickshell
import "../../theme"
import "../../services"
import ".."

// Lamps: OpenRGB. Pick a colour on the hue ring (plus saturation and brightness), apply it to every
// device or one, choose a device's effect mode, size addressable headers, load and save profiles,
// or let the lights follow the colour theme's accent. services/Rgb.qml drives the openrgb CLI.
Column {
    id: root

    spacing: 22

    property real hue: 0.11
    property real sat: 0.55
    property real val: 0.79
    readonly property color picked: Qt.hsva(hue, sat, val, 1)
    readonly property var swatches: [Theme.brass, Theme.brassBright, Theme.phosphor, Theme.signal, Theme.warn,
                                     Theme.green, "#7c9cc4", "#b48ab8", "#ffffff"]

    onPickedChanged: if (!hexIn.activeFocus) hexIn.text = Rgb.hex(picked)

    function setColor(c) {
        hue = Math.max(0, c.hsvHue);
        sat = c.hsvSaturation;
        val = c.hsvValue;
    }

    Component.onCompleted: {
        if (!Rgb.scanned) Rgb.scan();
        setColor(Theme.brass);
    }

    Text {
        visible: Rgb.scanned && !Rgb.available
        width: parent.width
        wrapMode: Text.Wrap
        text: "openrgb isn't installed · pacman -S openrgb"
        color: Theme.warn
        font.family: Theme.fontData
        font.pixelSize: Theme.dataSize
    }

    // ---------------------------------------------------------------- colour
    Section {
        visible: Rgb.available || !Rgb.scanned
        title: "colour"
        trailing: Rgb.busy ? "working…" : Rgb.devices.length + " devices"
        trailingColor: Rgb.busy ? Theme.phosphor : Theme.dim

        Item {
            width: parent.width
            height: Theme.lampRing * 2 + 16

            // Hue ring
            Item {
                id: ring
                width: Theme.lampRing * 2
                height: width
                y: 8
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const c = width / 2, r = c - 8;
                        for (let i = 0; i < 360; i++) {
                            const a0 = (i - 90) * Math.PI / 180, a1 = (i + 1.5 - 90) * Math.PI / 180;
                            ctx.strokeStyle = Qt.hsva(i / 360, 0.85, 0.95, 1);
                            ctx.lineWidth = 12;
                            ctx.beginPath(); ctx.arc(c, c, r, a0, a1); ctx.stroke();
                        }
                        ctx.strokeStyle = Theme.alpha(Theme.brass, 0.8);
                        ctx.lineWidth = 1;
                        ctx.beginPath(); ctx.arc(c, c, r + 8, 0, 2 * Math.PI); ctx.stroke();
                        ctx.beginPath(); ctx.arc(c, c, r - 8, 0, 2 * Math.PI); ctx.stroke();
                        for (let d = 0; d < 360; d += 15) {
                            const a = d * Math.PI / 180;
                            ctx.beginPath();
                            ctx.moveTo(c + (r + 8) * Math.cos(a), c + (r + 8) * Math.sin(a));
                            ctx.lineTo(c + (r + 13) * Math.cos(a), c + (r + 13) * Math.sin(a));
                            ctx.stroke();
                        }
                    }
                }
                // the picked colour, as a lens in the middle
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 58
                    height: width
                    radius: width / 2
                    color: root.picked
                    border.width: 2
                    border.color: Theme.bgDark
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.brass
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "#" + Rgb.hex(root.picked)
                        color: root.val > 0.6 && root.sat < 0.6 ? Theme.bgDark : Theme.starlight
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSize
                    }
                }
                // pointer on the ring
                Rectangle {
                    readonly property real a: root.hue * 2 * Math.PI - Math.PI / 2
                    readonly property real r: ring.width / 2 - 8
                    x: ring.width / 2 + r * Math.cos(a) - width / 2
                    y: ring.height / 2 + r * Math.sin(a) - height / 2
                    width: 18; height: 18; radius: 9
                    color: Qt.hsva(root.hue, 0.85, 0.95, 1)
                    border.width: 2.5
                    border.color: Theme.starlight
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 0.5; shadowOpacity: 0.7; shadowVerticalOffset: 1 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    function pick(m) {
                        const dx = m.x - width / 2, dy = m.y - height / 2;
                        if (Math.hypot(dx, dy) < width / 2 - 30) return;
                        let a = Math.atan2(dy, dx) + Math.PI / 2;
                        if (a < 0) a += 2 * Math.PI;
                        root.hue = Math.min(0.999, a / (2 * Math.PI));
                    }
                    onPressed: m => pick(m)
                    onPositionChanged: m => { if (pressed) pick(m); }
                }
            }

            Column {
                anchors.left: ring.right
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.verticalCenter: ring.verticalCenter
                spacing: 12
                Text { text: "saturation"; color: Theme.dim; font.family: Theme.fontData; font.pixelSize: Theme.dataSizeSmall }
                Dial { width: parent.width; value: root.sat; ink: root.picked; onMoved: v => root.sat = v }
                Text { text: "brightness"; color: Theme.dim; font.family: Theme.fontData; font.pixelSize: Theme.dataSizeSmall }
                Dial { width: parent.width; value: root.val; ink: root.picked; onMoved: v => root.val = v }
                // theme and common colours
                Flow {
                    width: parent.width
                    spacing: 7
                    Repeater {
                        model: root.swatches
                        Rectangle {
                            required property color modelData
                            width: 20; height: 20; radius: 10
                            color: modelData
                            border.width: 1
                            border.color: sw.containsMouse ? Theme.starlight : Theme.alpha(Theme.brass, 0.6)
                            MouseArea { id: sw; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setColor(parent.modelData) }
                        }
                    }
                }
                Row {
                    spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "#"; color: Theme.brass; font.family: Theme.fontData; font.pixelSize: Theme.dataSize }
                    Rectangle {
                        width: 90; height: 26; radius: 4
                        color: Theme.alpha(Theme.bgDark, 0.9)
                        border.width: 1
                        border.color: hexIn.activeFocus ? Theme.brassBright : Theme.border
                        TextInput {
                            id: hexIn
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.phosphor
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize
                            maximumLength: 6
                            validator: RegularExpressionValidator { regularExpression: /[0-9a-fA-F]{0,6}/ }
                            onAccepted: if (text.length === 6) root.setColor("#" + text)
                        }
                    }
                }
            }
        }

        Row {
            spacing: 8
            Link { text: "apply to all"; primary: true; enabled: !Rgb.busy && Rgb.devices.length > 0; onClicked: Rgb.setAll(root.picked) }
            Link { text: "lights off"; enabled: !Rgb.busy; onClicked: Rgb.setAll("#000000") }
            Link { text: "rescan"; enabled: !Rgb.busy; onClicked: Rgb.scan() }
        }
        Item {
            width: parent.width
            height: 28
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "follow the colour theme's accent"
                color: Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Rgb.followWallpaper
                onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper)
            }
        }
        Text {
            visible: Rgb.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: Rgb.error
            color: Theme.signal
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
    }

    // ---------------------------------------------------------------- devices
    Section {
        visible: Rgb.available
        title: "devices"
        Repeater {
            model: Rgb.devices
            Rectangle {
                id: dev
                required property var modelData
                property string mode: modelData.mode || Rgb.colorMode(modelData)
                width: parent.width
                height: devCol.implicitHeight + 20
                radius: 5
                color: Theme.alpha(Theme.bgDark, 0.7)
                border.width: 1
                border.color: Theme.alpha(Theme.border, 0.9)
                Column {
                    id: devCol
                    x: 12; y: 10
                    width: parent.width - 24
                    spacing: 8
                    Item {
                        width: parent.width
                        height: 26
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: dev.modelData.name; color: Theme.fg; font.family: Theme.fontData; font.pixelSize: Theme.dataSize }
                            Text { text: dev.modelData.type.toLowerCase(); color: Theme.dim; font.family: Theme.fontData; font.pixelSize: Theme.dataSizeSmall }
                        }
                        Link {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "apply colour"
                            enabled: !Rgb.busy
                            onClicked: Rgb.setDevice(dev.modelData, dev.mode, root.picked)
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 5
                        Repeater {
                            model: dev.modelData.modes
                            Link {
                                required property string modelData
                                mono: true
                                text: modelData.toLowerCase()
                                primary: dev.mode === modelData
                                onClicked: dev.mode = modelData
                            }
                        }
                    }
                    // Addressable headers: LED counts
                    Repeater {
                        model: Rgb.resizableZones(dev.modelData)
                        Item {
                            id: zone
                            required property var modelData
                            property int leds: modelData.leds
                            width: parent.width
                            height: 26
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: zone.modelData.name + "  ·  " + zone.leds + " leds" + (zone.modelData.leds === 0 ? "  ·  not set up" : "")
                                color: Theme.fg
                                font.family: Theme.fontData
                                font.pixelSize: Theme.dataSizeSmall
                            }
                            Row {
                                anchors.right: parent.right
                                spacing: 6
                                Link { text: "−"; mono: true; onClicked: zone.leds = Math.max(zone.modelData.min, zone.leds - 1) }
                                Link { text: "+"; mono: true; onClicked: zone.leds = Math.min(zone.modelData.max, zone.leds + 1) }
                                Link { text: "set"; enabled: !Rgb.busy && zone.leds !== zone.modelData.leds; onClicked: Rgb.setZoneSize(dev.modelData, zone.modelData.index, zone.leds) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- profiles
    Section {
        visible: Rgb.available
        title: "profiles"
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: Rgb.profiles
                Link { required property string modelData; text: modelData; mono: true; enabled: !Rgb.busy; onClicked: Rgb.loadProfile(modelData) }
            }
        }
        Text {
            visible: Rgb.profiles.length === 0
            text: "no saved profiles yet"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }
        Row {
            spacing: 8
            Rectangle {
                width: 220; height: 28; radius: 4
                color: Theme.alpha(Theme.bgDark, 0.9)
                border.width: 1
                border.color: profileName.activeFocus ? Theme.brassBright : Theme.border
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: profileName.text === ""
                    text: "new profile name"
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
                TextInput {
                    id: profileName
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSize
                    onAccepted: if (text.trim()) { Rgb.saveProfile(text.trim()); text = ""; }
                }
            }
            Link {
                text: "save"
                enabled: !Rgb.busy && profileName.text.trim() !== ""
                onClicked: { Rgb.saveProfile(profileName.text.trim()); profileName.text = ""; }
            }
        }
    }
}
