import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

// Now playing, visualizer, volume mixer and output picker
Flickable {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sourceCandidates: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    // Real inputs only (skips internal/raw device nodes)
    readonly property var sources: sourceCandidates.filter(n => n.properties?.["media.class"] === "Audio/Source")
    readonly property bool testing: Cava.source !== ""

    function startTest() {
        if (source)
            Cava.source = source.name;
    }

    readonly property var allStreams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)
    // App playback only (not capture streams like cava's)
    readonly property var streams: allStreams.filter(n => n.properties?.["media.class"] === "Stream/Output/Audio")

    function deviceName(node) {
        return node?.nickname || node?.description || node?.name || "";
    }

    function deviceDetail(node) {
        const profile = node?.properties?.["device.profile.description"] ?? "";
        // Some nicknames repeat the profile; show the full description then
        return profile && profile !== node?.nickname ? profile : node?.description ?? "";
    }

    function volumeIcon(node) {
        const v = node?.audio?.volume ?? 0;
        if (node && !node.isSink && !node.isStream)
            return String.fromCodePoint(node.audio?.muted || v === 0 ? 0xF036D : 0xF036C);
        if (!node?.audio || node.audio.muted || v === 0) return String.fromCodePoint(0xF0581);
        if (v < 0.34) return String.fromCodePoint(0xF057F);
        if (v < 0.67) return String.fromCodePoint(0xF0580);
        return String.fromCodePoint(0xF057E);
    }

    function deviceIcon(node) {
        const s = ((node.description ?? "") + " " + (node.name ?? "")).toLowerCase();
        if (s.includes("hdmi") || s.includes("displayport")) return String.fromCodePoint(0xF0379);
        if (s.includes("headphone") || s.includes("headset")) return String.fromCodePoint(0xF02CB);
        return String.fromCodePoint(0xF04C3);
    }

    function appIcon(node) {
        const p = node.properties ?? {};
        const name = p["application.icon-name"] || p["application.process.binary"] || "";
        return name && Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
    }

    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Volume and properties are only populated for tracked nodes
    PwObjectTracker {
        objects: root.sinks.concat(root.allStreams, root.sourceCandidates)
    }

    ColumnLayout {
        id: content

        width: root.width
        spacing: 10

        // Now playing, over a blurred copy of the art
        ClippingRectangle {
            Layout.fillWidth: true
            implicitHeight: nowPlaying.height + 32
            radius: 0
            color: Theme.bgDark
            border.width: 1
            border.color: Theme.border

            Image {
                id: backdrop
                anchors.fill: parent
                source: nowPlaying.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 128
                sourceSize.height: 128
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: backdrop
                visible: backdrop.status === Image.Ready
                blurEnabled: true
                blur: 1
                blurMax: 64
                saturation: 0.2
                opacity: 0.45
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.4) }
                    GradientStop { position: 1; color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85) }
                }
            }

            MediaPanel {
                id: nowPlaying
                x: 16
                y: 16
                width: parent.width - 32
            }
        }

        // Visualizer
        Card {
            title: "Visualizer"
            trailing: root.testing ? "MIC TEST" : ""

            Item {
                Layout.fillWidth: true
                implicitHeight: 72

                Row {
                    id: bars

                    readonly property real barWidth: (width - spacing * (Cava.bars - 1)) / Cava.bars

                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        model: Cava.bars

                        Rectangle {
                            required property int index
                            readonly property real value: Cava.values[index] ?? 0

                            anchors.verticalCenter: parent.verticalCenter
                            width: bars.barWidth
                            height: Math.max(3, value * bars.height)
                            radius: 0
                            // Blue on the bass end fading to purple on the treble end
                            color: Qt.tint(Theme.accent, Qt.rgba(Theme.purple.r, Theme.purple.g, Theme.purple.b, index / Cava.bars))
                            opacity: 0.45 + value * 0.55
                        }
                    }
                }
            }
        }

        // Volume
        Card {
            title: "Volume"
            trailing: root.sink ? Math.round((root.sink.audio?.volume ?? 0) * 100) + "%" : ""

            VolumeRow {
                node: root.sink
                label: root.deviceName(root.sink) || "No output"
                sublabel: root.deviceDetail(root.sink)
                big: true
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.hover
                visible: root.streams.length > 0
            }

            Repeater {
                model: root.streams

                VolumeRow {
                    required property PwNode modelData
                    node: modelData
                    label: modelData.properties?.["application.name"] || modelData.description || modelData.name
                    sublabel: modelData.properties?.["media.name"] ?? ""
                    icon: root.appIcon(modelData)
                }
            }

            Text {
                visible: root.streams.length === 0
                text: "No apps playing audio"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }
        }

        // Output picker
        Card {
            title: "Output"

            Repeater {
                model: root.sinks

                DeviceRow {
                    required property PwNode modelData
                    node: modelData
                    current: modelData === root.sink
                    icon: root.deviceIcon(modelData)
                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
        }

        // Input picker + mic test
        Card {
            title: "Input"
            trailing: root.source ? Math.round((root.source.audio?.volume ?? 0) * 100) + "%" : ""

            VolumeRow {
                node: root.source
                label: root.deviceName(root.source) || "No input"
                sublabel: root.deviceDetail(root.source)
                big: true
            }

            // Tester: routes the mic into cava so the visualizers react to it
            Rectangle {
                id: tester

                Layout.fillWidth: true
                implicitHeight: 40
                radius: 0
                enabled: !!root.source
                color: root.testing ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15)
                     : testMouse.containsMouse ? Theme.hover : "transparent"
                border.width: 1
                border.color: root.testing ? Theme.danger : Theme.hover

                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    // Pulsing record dot while testing
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.testing
                        width: 8
                        height: 8
                        radius: 0
                        color: Theme.danger

                        SequentialAnimation on opacity {
                            running: root.testing
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.testing
                        text: String.fromCodePoint(0xF036C)
                        font.family: Theme.font
                        font.pixelSize: 14
                        color: Theme.fg
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.testing ? "Testing — speak, then click to stop" : "Test microphone"
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                        color: root.testing ? Theme.danger : Theme.fg
                    }
                }

                MouseArea {
                    id: testMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.testing ? Cava.source = "" : root.startTest()
                }
            }

            Repeater {
                model: root.sources

                DeviceRow {
                    required property PwNode modelData
                    node: modelData
                    current: modelData === root.source
                    icon: String.fromCodePoint(0xF036C)
                    onClicked: {
                        Pipewire.preferredDefaultAudioSource = modelData;
                        // Keep testing, on the newly picked mic
                        if (root.testing)
                            Cava.source = modelData.name;
                    }
                }
            }
        }
    }

    // --- Components ---

    component Card: Rectangle {
        id: card

        property string title
        property string trailing
        default property alias items: body.data

        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        radius: 0
        color: Theme.bgDark
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: col

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: card.title
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                    color: Theme.dim
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: card.trailing
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.accent
                }
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: 12
            }
        }
    }

    component VolumeRow: RowLayout {
        id: vr

        property PwNode node
        property string label
        property string sublabel
        property string icon
        property bool big: false
        readonly property bool muted: node?.audio?.muted ?? false

        Layout.fillWidth: true
        spacing: 12

        // Mute toggle, showing the app icon when there is one
        Rectangle {
            implicitWidth: vr.big ? 40 : 34
            implicitHeight: implicitWidth
            radius: 0
            color: vr.muted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15)
                 : muteMouse.containsMouse ? Theme.border : Theme.hover

            Image {
                anchors.centerIn: parent
                visible: vr.icon !== ""
                source: vr.icon
                sourceSize.width: 22
                sourceSize.height: 22
                opacity: vr.muted ? 0.4 : 1
            }

            Text {
                anchors.centerIn: parent
                visible: vr.icon === "" || vr.muted
                text: root.volumeIcon(vr.node)
                font.family: Theme.font
                font.pixelSize: vr.big ? 18 : 15
                color: vr.muted ? Theme.danger : Theme.fg
            }

            MouseArea {
                id: muteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (vr.node?.audio) vr.node.audio.muted = !vr.node.audio.muted
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: vr.label
                    elide: Text.ElideRight
                    Layout.maximumWidth: 180
                    font.family: Theme.font
                    font.pixelSize: vr.big ? 13 : 12
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    Layout.fillWidth: true
                    text: vr.sublabel
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.dim
                }

                Text {
                    visible: !vr.big
                    text: Math.round((vr.node?.audio?.volume ?? 0) * 100) + "%"
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }

            Slider {
                Layout.fillWidth: true
                value: vr.node?.audio?.volume ?? 0
                color: vr.muted ? Theme.border : Theme.accent
                onMoved: v => {
                    if (!vr.node?.audio)
                        return;
                    vr.node.audio.volume = v;
                    if (vr.node.audio.muted && v > 0)
                        vr.node.audio.muted = false;
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: dev

        property PwNode node
        property bool current
        property string icon
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 48
        radius: 0
        color: current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
             : devMouse.containsMouse ? Theme.hover : "transparent"
        border.width: current ? 1 : 0
        border.color: Theme.accent

        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Text {
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                text: dev.icon
                font.family: Theme.font
                font.pixelSize: 18
                color: dev.current ? Theme.accent : Theme.dim
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: root.deviceName(dev.node)
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    color: dev.current ? Theme.fg : Theme.dim
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.deviceDetail(dev.node)
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: dev.current ? Theme.dim : Theme.border
                }
            }

            Text {
                visible: dev.current
                text: "\uf00c"
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.accent
            }
        }

        MouseArea {
            id: devMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dev.clicked()
        }
    }
}
