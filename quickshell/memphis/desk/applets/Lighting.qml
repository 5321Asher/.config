import QtQuick
import Quickshell
import "../../theme"
import "../../widgets"
import "../../services"
import ".."

// Lighting Properties (the RGB lights, through OpenRGB):
//   Colour     98's colour picker: the 48 basic colours, the rainbow and the brightness strip; apply
//              to every light, turn them off, or let them follow the colour scheme
//   Devices    each device's mode (direct, static, breathing…) and its resizable LED zones
//   Profiles   OpenRGB profiles: load one, or save the lights as they are
Props {
    id: root

    title: "Lighting Properties"
    icon: "preferences-desktop-color"
    tabs: ["Colour", "Devices", "Profiles"]

    Component.onCompleted: if (!Rgb.scanned) Rgb.scan()

    property real hue: 0.6
    property real sat: 1
    property real lum: 0.5
    readonly property color picked: Qt.hsla(hue, sat, lum, 1)
    function pick(c) {
        const q = Qt.color(c);
        hue = Math.max(0, q.hslHue); sat = q.hslSaturation; lum = q.hslLightness;
    }
    property int devSel: 0
    property int profSel: -1

    // 98's basic colours
    readonly property var basic: [
        "#ff8080", "#ffff80", "#80ff80", "#00ff80", "#80ffff", "#0080ff", "#ff80c0", "#ff80ff",
        "#ff0000", "#ffff00", "#80ff00", "#00ff40", "#00ffff", "#0080c0", "#8080c0", "#ff00ff",
        "#804040", "#ff8040", "#00ff00", "#008080", "#004080", "#8080ff", "#800040", "#ff0080",
        "#800000", "#ff8000", "#008000", "#008040", "#0000ff", "#0000a0", "#800080", "#8000ff",
        "#400000", "#804000", "#004000", "#004040", "#000080", "#000040", "#400040", "#400080",
        "#000000", "#808000", "#808040", "#808080", "#408080", "#c0c0c0", "#400040", "#ffffff",
    ]

    // ---------------------------------------------------------------- Colour
    Item {
        Column {
            id: left
            spacing: 6
            Txt {
                visible: Rgb.scanned && !Rgb.available
                text: "OpenRGB isn't installed, or found no lights."
                color: Theme.danger
            }
            Txt { text: "Basic colours:" }
            Grid {
                columns: 8
                spacing: 4
                Repeater {
                    model: root.basic
                    Item {
                        required property string modelData
                        width: 26; height: 22
                        Rectangle {
                            anchors.fill: parent
                            visible: Qt.color(modelData).toString() === root.picked.toString()
                            color: "transparent"; border.width: 1; border.color: Theme.dkShadow
                        }
                        Bevel { anchors.fill: parent; anchors.margins: 2; kind: "sunken"; fill: modelData }
                        MouseArea { anchors.fill: parent; onClicked: root.pick(modelData) }
                    }
                }
            }
            Item { width: 1; height: 8 }
            Check { text: "Follow the colour scheme"; enabled: Rgb.available; checked: Rgb.followWallpaper; onToggled: Rgb.setFollowWallpaper(!Rgb.followWallpaper) }
            Row {
                spacing: 6
                Btn { text: "Apply to All"; isDefault: true; enabled: !Rgb.busy && Rgb.devices.length > 0; onClicked: Rgb.setAll(root.picked) }
                Btn { text: "Lights Off"; enabled: !Rgb.busy; onClicked: Rgb.setAll("#000000") }
            }
            Txt { text: Rgb.busy ? "Working…" : Rgb.devices.length + " device(s)" }
            Txt { visible: Rgb.error !== ""; width: 250; wrapMode: Text.Wrap; color: Theme.danger; text: Rgb.error }
        }

        // the rainbow (hue across, saturation down) and the brightness strip
        Bevel {
            id: spectrum
            x: left.width + 20
            y: 22
            width: 180; height: 180
            kind: "sunken"
            Canvas {
                id: rainbow
                anchors.fill: parent
                anchors.margins: 2
                onPaint: {
                    const ctx = getContext("2d");
                    for (let x = 0; x < width; x += 2)
                        for (let y = 0; y < height; y += 2) {
                            ctx.fillStyle = Qt.hsla(x / width, 1 - y / height, 0.5, 1);
                            ctx.fillRect(x, y, 2, 2);
                        }
                }
                // 98's crosshair
                Item {
                    x: root.hue * rainbow.width - 9
                    y: (1 - root.sat) * rainbow.height - 9
                    width: 19; height: 19
                    Rectangle { x: 0; y: 8; width: 7; height: 3; color: "#000000" }
                    Rectangle { x: 12; y: 8; width: 7; height: 3; color: "#000000" }
                    Rectangle { x: 8; y: 0; width: 3; height: 7; color: "#000000" }
                    Rectangle { x: 8; y: 12; width: 3; height: 7; color: "#000000" }
                }
                MouseArea {
                    anchors.fill: parent
                    function at(e) {
                        root.hue = Math.max(0, Math.min(0.999, e.x / width));
                        root.sat = Math.max(0, Math.min(1, 1 - e.y / height));
                        if (root.lum < 0.05 || root.lum > 0.95) root.lum = 0.5;
                    }
                    onPressed: e => at(e)
                    onPositionChanged: e => { if (pressed) at(e); }
                }
            }
        }
        Bevel {
            id: strip
            x: spectrum.x + spectrum.width + 10
            y: spectrum.y
            width: 18; height: 180
            kind: "sunken"
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#ffffff" }
                    GradientStop { position: 0.5; color: Qt.hsla(root.hue, root.sat, 0.5, 1) }
                    GradientStop { position: 1; color: "#000000" }
                }
            }
            MouseArea {
                anchors.fill: parent
                onPressed: e => root.lum = Math.max(0, Math.min(1, 1 - e.y / height))
                onPositionChanged: e => { if (pressed) root.lum = Math.max(0, Math.min(1, 1 - e.y / height)); }
            }
        }
        Glyph { x: strip.x + strip.width + 2; y: strip.y + (1 - root.lum) * strip.height - 4; kind: "left" }

        Row {
            x: spectrum.x
            y: spectrum.y + spectrum.height + 12
            spacing: 10
            Column {
                spacing: 2
                Bevel { width: 80; height: 56; kind: "sunken"; fill: root.picked }
                Txt { text: "Colour|Solid" }
            }
            Column {
                spacing: 4
                Row {
                    spacing: 6
                    Txt { width: 40; height: Theme.field; text: "Hex:" }
                    Field {
                        width: 100
                        text: "#" + Rgb.hex(root.picked)
                        onAccepted: if (/^#?[0-9a-f]{6}$/i.test(text.trim())) root.pick(text.trim().startsWith("#") ? text.trim() : "#" + text.trim())
                    }
                }
                Txt { text: "Red: " + Math.round(root.picked.r * 255) + "  Green: " + Math.round(root.picked.g * 255) + "  Blue: " + Math.round(root.picked.b * 255) }
            }
        }
    }

    // ---------------------------------------------------------------- Devices
    Column {
        spacing: 8
        ListBox {
            width: parent.width
            height: 200
            model: Rgb.devices
            currentIndex: root.devSel
            onClicked: i => root.devSel = i
            iconOf: d => "preferences-desktop-color"
            columns: [
                { title: "Device", width: 0, text: d => d.name },
                { title: "Type", width: 120, text: d => d.type },
            ]
        }
        Item {
            id: devPane
            width: parent.width
            height: 200
            readonly property var dev: Rgb.devices[root.devSel] ?? null
            property string mode: dev ? (dev.mode || Rgb.colorMode(dev)) : ""
            onDevChanged: mode = dev ? (dev.mode || Rgb.colorMode(dev)) : ""
            visible: !!dev
            Column {
                spacing: 8
                Row {
                    spacing: 8
                    Txt { height: Theme.field; text: "Mode:" }
                    Combo {
                        width: 200
                        model: devPane.dev?.modes ?? []
                        currentIndex: (devPane.dev?.modes ?? []).indexOf(devPane.mode)
                        onChosen: i => devPane.mode = devPane.dev.modes[i]
                    }
                    Btn { text: "Set Colour"; enabled: !Rgb.busy; onClicked: Rgb.setDevice(devPane.dev, devPane.mode, root.picked) }
                }
                Txt { visible: !!devPane.dev && Rgb.resizableZones(devPane.dev).length > 0; text: "LED zones:" }
                Repeater {
                    model: devPane.dev ? Rgb.resizableZones(devPane.dev) : []
                    Row {
                        id: zone
                        required property var modelData
                        property int leds: modelData.leds
                        spacing: 6
                        Txt { width: 190; height: Theme.button; elide: Text.ElideRight; text: zone.modelData.name + (zone.modelData.leds === 0 ? " (not set up)" : "") }
                        Btn { width: 32; implicitWidth: 32; padding: 0; text: "−"; onClicked: zone.leds = Math.max(zone.modelData.min, zone.leds - 1) }
                        Txt { width: 70; height: Theme.button; horizontalAlignment: Text.AlignHCenter; text: zone.leds + " LEDs" }
                        Btn { width: 32; implicitWidth: 32; padding: 0; text: "+"; onClicked: zone.leds = Math.min(zone.modelData.max, zone.leds + 1) }
                        Btn { text: "Set"; enabled: !Rgb.busy && zone.leds !== zone.modelData.leds; onClicked: Rgb.setZoneSize(devPane.dev, zone.modelData.index, zone.leds) }
                    }
                }
            }
        }
        Btn { text: "Look Again"; enabled: !Rgb.busy; onClicked: Rgb.scan() }
    }

    // ---------------------------------------------------------------- Profiles
    Column {
        spacing: 8
        Txt { text: "Saved profiles:" }
        ListBox {
            width: parent.width
            height: 260
            model: Rgb.profiles
            currentIndex: root.profSel
            onClicked: i => root.profSel = i
            onActivated: i => Rgb.loadProfile(Rgb.profiles[i])
            iconOf: p => "document-open"
        }
        Btn { text: "Load"; enabled: root.profSel >= 0 && !Rgb.busy; onClicked: Rgb.loadProfile(Rgb.profiles[root.profSel]) }
        Item { width: 1; height: 10 }
        Txt { text: "Save the lights as they are now:" }
        Row {
            spacing: 8
            Field { id: profName; width: 260; placeholder: "Profile name"; onAccepted: if (text.trim()) { Rgb.saveProfile(text.trim()); text = ""; } }
            Btn { text: "Save"; enabled: !Rgb.busy && profName.text.trim() !== ""; onClicked: { Rgb.saveProfile(profName.text.trim()); profName.text = ""; } }
        }
    }
}
