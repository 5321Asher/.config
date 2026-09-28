import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../flyouts"

// Windows 11's volume and brightness flyout: a small pill above the taskbar, centred, with the icon,
// a bar and the number; it shows when the level changes (keys, apps) and fades after a moment.
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Flyouts.focusedScreen()?.name) ?? Quickshell.screens[0]
    anchors { bottom: true }
    margins { bottom: 24 }
    exclusionMode: ExclusionMode.Normal
    implicitWidth: 196
    implicitHeight: 50
    color: "transparent"
    visible: shown || fade.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "disguise-osd"
    mask: Region {}

    property bool shown: false
    property string what: "volume"
    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink].filter(n => n) }
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real level: what === "volume" ? vol : Backlight.value

    // ignore the first values (start-up), and changes made from Quick Settings while it's open
    property bool ready: false
    Timer { running: true; interval: 1500; onTriggered: root.ready = true }
    function pop(w) {
        if (!ready || (Flyouts.isOpen && Flyouts.kind === "quick")) return;
        what = w;
        shown = true;
        hide.restart();
    }
    onVolChanged: pop("volume")
    onMutedChanged: pop("volume")
    Connections { target: Backlight; function onValueChanged() { root.pop("brightness"); } }
    Timer { id: hide; interval: 1600; onTriggered: root.shown = false }

    Item {
        id: pill
        anchors.fill: parent
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.normal } }
        Acrylic { anchors.fill: parent; radius: height / 2; tintAlpha: Theme.dark ? 0.94 : 0.92 }
        Glyph {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            g: root.what === "brightness" ? "" : root.muted ? "" : root.vol > 0.66 ? "" : root.vol > 0.33 ? "" : root.vol > 0 ? "" : ""
            size: 16
        }
        Rectangle {
            x: 48; width: 100; height: 4; radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.strong
            Rectangle { width: parent.width * Math.min(1, root.level); height: parent.height; radius: 2; color: root.muted && root.what === "volume" ? Theme.text3 : Theme.accent
                        Behavior on width { NumberAnimation { duration: 80 } } }
        }
        Txt { x: 158; width: 28; height: parent.height; text: Math.round(root.level * 100); size: Theme.caption }
    }
}
