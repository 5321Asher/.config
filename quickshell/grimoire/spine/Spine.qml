import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../services"
import "../codex"
import "../utilities"

// The spine, down the left of every screen: the book's leather spine with its raised bands, and
// between them the reagents: the heat crystal (CPU temperature), two potion vials (CPU and memory)
// and the mana bar (the battery). At its foot the candle stands in its dish and burns through your
// session (spine/Candle.qml). Hover any of them for a note in the margin; click to open its page of
// the codex (the candle opens the Hourglass).
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; bottom: true }
    implicitWidth: Theme.spineWidth
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "grimoire-spine"
    exclusiveZone: Theme.spineWidth

    Component.onCompleted: SysStats.active = true
    Connections {
        target: Debug
        function onGrab(what, path) { if (what === "spine" && root.modelData === Quickshell.screens[0]) body.grabToImage(r => r.saveToFile(path)); }
    }

    // if Hyprland gave us the whole height, the bar's corner covers our top
    readonly property real top: height >= (modelData?.height ?? 0) - 2 ? Theme.barHeight : 0

    readonly property var s: SysStats.data
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real charge: hasBattery ? (battery.percentage > 1 ? battery.percentage / 100 : battery.percentage) : 1
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
    function gb(b) { return (b / 1073741824).toFixed(1); }

    Item {
        id: body
        anchors.fill: parent

        Leather { anchors.fill: parent; tooled: false; opacity_: 0.97 }
        // the gilt edge down the right, and a sunken line inside it
        Rectangle { x: parent.width - 3; width: 2; height: parent.height; color: Theme.gold }
        Rectangle { x: parent.width - 4; width: 1; height: parent.height; color: Theme.alpha(Theme.goldDeep, 0.9) }
        Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: Qt.alpha("#000000", 0.5) }
        Rectangle { x: 5; width: 1; height: parent.height; color: Qt.alpha("#000000", Theme.light ? 0.12 : 0.35) }
        Rectangle { x: 6; width: 1; height: parent.height; color: Theme.alpha(Theme.tooling, 0.5) }

        Column {
            id: shelf
            y: root.top + 10
            width: parent.width - 3
            spacing: 0

            Band {}
            Compartment {
                page: "telemetry"
                note: "The heat crystal. The processor runs at " + Math.round(root.s?.cpu?.temp ?? 0) + "°C" + ((root.s?.gpu?.temp ?? 0) > 0 ? ", the graphics at " + Math.round(root.s.gpu.temp) + "°C." : ".")
                label: "heat"
                value: Math.round(root.s?.cpu?.temp ?? 0) + "°"
                Crystal { anchors.horizontalCenter: parent.horizontalCenter; temp: root.s?.cpu?.temp ?? 40 }
            }
            Band {}
            Compartment {
                page: "telemetry"
                note: "The processor's draught: " + Math.round(root.s?.cpu?.usage ?? 0) + "% at work, load " + (root.s?.cpu?.load ?? []).join(" ") + "."
                label: "anima"
                value: Math.round(root.s?.cpu?.usage ?? 0) + "%"
                Vial { anchors.horizontalCenter: parent.horizontalCenter; shape: "flask"; potion: Theme.arcane; value: (root.s?.cpu?.usage ?? 0) / 100 }
            }
            Band {}
            Compartment {
                page: "telemetry"
                note: "The memory's elixir: " + (root.s ? root.gb(root.s.mem.used) + " of " + root.gb(root.s.mem.total) + " GB held." : "…")
                label: "memory"
                value: root.s ? Math.round(root.s.mem.used / root.s.mem.total * 100) + "%" : ""
                Vial { anchors.horizontalCenter: parent.horizontalCenter; shape: "tube"; potion: Theme.green; height: 56; width: 30
                       value: root.s ? root.s.mem.used / root.s.mem.total : 0 }
            }
            Band {}
            Compartment {
                page: "hangar"
                note: !root.hasBattery ? "No battery: the book draws on the ley line (mains power)."
                    : "Mana " + Math.round(root.charge * 100) + "%" + (root.charging ? ", drawing from the ley line." : root.battery.timeToEmpty > 0 ? ", about " + Math.round(root.battery.timeToEmpty / 60) + " minutes left." : ".")
                label: "mana"
                value: root.hasBattery ? Math.round(root.charge * 100) + "%" : "ley"
                Mana { anchors.horizontalCenter: parent.horizontalCenter; value: root.charge; charging: root.charging; present: root.hasBattery
                       height: Math.max(60, Math.min(104, root.height - root.top - 620)) }
            }
            Band {}
        }

        // ---------------------------------------------------------------- the spine's title
        // in the room between the reagents and the candle, lettered in gold down the spine
        Item {
            id: titleBox
            y: shelf.y + shelf.height
            width: parent.width - 3
            height: Math.max(0, candle.y + candle.waxTop - 150 - y)
            visible: height > 240
            Column {
                anchors.centerIn: parent
                spacing: 14
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "✦"; color: Theme.alpha(Theme.gold, 0.7); font.family: Theme.symbols; font.pixelSize: 10 }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: spineTitle.height
                    height: spineTitle.width
                    Text {
                        id: spineTitle
                        anchors.centerIn: parent
                        rotation: 90
                        text: "Grimoire"
                        color: Theme.gold
                        font.family: Theme.blackletter
                        font.pixelSize: 30
                        style: Text.Sunken
                        styleColor: Qt.alpha("#000000", 0.55)
                    }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "✦"; color: Theme.alpha(Theme.gold, 0.7); font.family: Theme.symbols; font.pixelSize: 10 }
            }
        }

        // ---------------------------------------------------------------- the candle
        Candle {
            id: candle
            x: 0
            height: Math.min(parent.height - shelf.y - shelf.height - 32, 430)
            y: parent.height - height - 26
            width: parent.width - 3
        }
        Body {
            anchors.horizontalCenter: candle.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            text: candle.burnText()
            italic: true
            color: Theme.dim
            font.pixelSize: 12
        }
        MouseArea {
            id: candleMouse
            x: 0; y: candle.y + candle.waxTop - 60
            width: candle.width
            height: parent.height - y
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: CodexState.toggleTo("chronometer")
            onContainsMouseChanged: tip.show(containsMouse ? candleMouse : null,
                "The candle was lit at " + candle.litAt() + " and has burned " + candle.burnText() + (candle.guttering ? ". It gutters: a long session." : "."))
        }
    }

    // a raised band across the spine: a ridge of leather with a gold fillet either side
    component Band: Item {
        width: parent.width
        height: 14
        Rectangle { y: 1; width: parent.width; height: 1; color: Theme.alpha(Theme.gold, 0.75) }
        Rectangle {
            y: 3; width: parent.width; height: 8
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(Theme.leather, Theme.light ? 1.06 : 1.45) }
                GradientStop { position: 0.5; color: Theme.leather }
                GradientStop { position: 1; color: Qt.darker(Theme.leather, 1.6) }
            }
        }
        Rectangle { y: 12; width: parent.width; height: 1; color: Theme.alpha(Theme.gold, 0.75) }
    }

    // a panel between two bands: the reagent, then its name and reading
    component Compartment: Item {
        id: comp
        default property alias content: holder.data
        property string page
        property string note
        property string label
        property string value
        width: parent.width
        height: holder.childrenRect.height + 50
        Item { id: holder; y: 10; width: parent.width; height: childrenRect.height }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            Caps { anchors.horizontalCenter: parent.horizontalCenter; text: comp.label; color: Theme.alpha(Theme.dim, 0.9); font.pixelSize: 9; font.letterSpacing: 1 }
            Body { anchors.horizontalCenter: parent.horizontalCenter; text: comp.value; color: Theme.fg; font.pixelSize: 13; strong: true }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: CodexState.toggleTo(comp.page)
            onContainsMouseChanged: tip.show(containsMouse ? comp : null, comp.note)
        }
        onNoteChanged: if (tip.target === comp) tip.text = note
    }

    // a note in the margin: a slip of parchment beside the spine
    PopupWindow {
        id: tip
        property Item target: null
        property string text: ""
        function show(t, s) {
            if (t) { target = t; text = s; hideLater.stop(); visible = true; }
            else hideLater.restart();
        }
        Timer { id: hideLater; interval: 120; onTriggered: { tip.visible = false; tip.target = null; } }
        anchor.window: root
        anchor.rect.x: root.width + 6
        anchor.rect.y: tip.target ? tip.target.mapToItem(null, 0, 0).y + tip.target.height / 2 - tip.implicitHeight / 2 : 0
        implicitWidth: 240
        implicitHeight: noteText.implicitHeight + 22
        color: "transparent"
        visible: false
        Parchment { anchors.fill: parent; age: 0.3 }
        Body {
            id: noteText
            x: 12; y: 11
            width: parent.width - 24
            wrapMode: Text.Wrap
            text: tip.text
            italic: true
            font.pixelSize: 14
        }
    }
}
