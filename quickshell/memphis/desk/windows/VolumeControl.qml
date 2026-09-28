import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../theme"
import "../../widgets"
import "../../menus"
import ".."

// Volume Control, 98's mixer: a column per line, each with its name, a vertical fader and a Mute
// check box. First the speakers ("Volume Control", whose Mute is "Mute all"), then the microphone,
// then one column for every program playing sound. Options → Properties picks the devices.
Win {
    id: root

    title: "Volume Control"
    icon: "multimedia-volume-control"
    minButton: true
    onMinRequested: closeRequested()
    status: sink ? root.deviceName(sink) : "No playback device"
    menus: [
        { title: "Options", items: () => [
            { text: "Properties", bold: true, run: () => Desk.show("applet:multimedia", { tab: "Audio" }) },
            { sep: true },
            { text: "Exit", run: () => root.closeRequested() },
        ] },
        { title: "Help", items: () => [{ text: "Help Topics", run: () => Desk.show("help") }] },
    ]
    onMenuRequested: (menu, x, y) => Menus.show(Desk.wins.volume?.screen ?? Desk.focusedScreen(), "menubar", menu.items(), x, y, {})

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream
        && n.properties?.["media.class"] === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.streams) }

    function deviceName(n) { return n?.nickname || n?.description || n?.name || ""; }

    readonly property var lines: [
        { node: sink, name: "Volume Control", icon: "audio-speakers", mute: "Mute all", master: true },
        { node: source, name: "Microphone", icon: "audio-input-microphone", mute: "Mute" },
    ].concat(streams.map(s => ({
        node: s,
        name: s.properties?.["application.name"] || s.name || "Program",
        icon: s.properties?.["application.icon-name"] || "audio-x-generic",
        mute: "Mute",
    })))

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 6
        contentWidth: cols.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id: cols
            height: flick.height
            Repeater {
                model: root.lines
                Row {
                    id: line
                    required property var modelData
                    required property int index
                    height: cols.height
                    Sep { vertical: true; height: parent.height - 10; y: 5; visible: line.index > 0 }
                    Column {
                        width: 128
                        height: parent.height
                        spacing: 6
                        topPadding: 6
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            Icon { name: line.modelData.icon; size: 20; anchors.verticalCenter: parent.verticalCenter }
                            Txt {
                                width: Math.min(implicitWidth, 96)
                                elide: Text.ElideRight
                                text: line.modelData.name
                                bold: line.modelData.master ?? false
                            }
                        }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Volume:" }
                        TrackBar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            vertical: true
                            width: 40
                            height: parent.height - 130
                            ticks: 7
                            enabled: !!line.modelData.node?.audio
                            value: line.modelData.node?.audio?.volume ?? 0
                            onMoved: v => { if (line.modelData.node?.audio) line.modelData.node.audio.volume = v; }
                        }
                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round((line.modelData.node?.audio?.volume ?? 0) * 100) + "%"
                        }
                        Check {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: line.modelData.mute
                            enabled: !!line.modelData.node?.audio
                            checked: line.modelData.node?.audio?.muted ?? false
                            onToggled: line.modelData.node.audio.muted = !line.modelData.node.audio.muted
                        }
                    }
                }
            }
        }
    }
}
