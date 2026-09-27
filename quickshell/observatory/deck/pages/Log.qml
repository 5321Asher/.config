import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../../theme"
import "../../services"
import ".."

// Transmission log: every notification until you dismiss it, newest first, with do-not-disturb
// and clear-all. Click an entry to run its default action; × dismisses it.
Column {
    id: root

    spacing: 22
    Component.onCompleted: Transmissions.unread = 0

    property real now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = Date.now() }

    function ago(id) {
        const t = Transmissions.times[id];
        if (!t) return "";
        const m = Math.floor((root.now - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + "m";
        const h = Math.floor(m / 60);
        return h < 24 ? h + "h" : Math.floor(h / 24) + "d";
    }
    function plain(s) {
        return (s ?? "").replace(/<br\s*\/?>/gi, " ").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }

    Section {
        title: "receiver"
        Item {
            width: parent.width
            height: 30
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Transmissions.dnd ? "do not disturb · only priority transmissions pop up" : "all transmissions pop up"
                color: Transmissions.dnd ? Theme.warn : Theme.fg
                font.family: Theme.fontData
                font.pixelSize: Theme.dataSizeSmall
            }
            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Transmissions.dnd
                onToggled: Transmissions.dnd = !Transmissions.dnd
            }
        }
    }

    Section {
        title: "log"
        trailing: Transmissions.history.length + " kept"

        Link {
            visible: Transmissions.history.length > 0
            text: "clear all"
            glyph: "\u{f0b5d}"
            onClicked: Transmissions.clearAll()
        }

        Text {
            visible: Transmissions.history.length === 0
            text: "silence · no transmissions logged"
            color: Theme.dim
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSize
        }

        Repeater {
            model: Transmissions.history

            Item {
                id: entry
                required property Notification modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property string iconSrc: {
                    const img = modelData.image ?? "";
                    if (img.startsWith("image://icon/")) {
                        const n = img.slice(13);
                        return Quickshell.hasThemeIcon(n) ? Quickshell.iconPath(n) : "";
                    }
                    if (img !== "") return img.startsWith("/") ? "file://" + img : img;
                    const a = modelData.appIcon ?? "";
                    if (a.startsWith("/")) return "file://" + a;
                    return a !== "" && Quickshell.hasThemeIcon(a) ? Quickshell.iconPath(a) : "";
                }
                width: parent.width
                height: body.implicitHeight + 18

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: hover.hovered ? Theme.alpha(Theme.hover, 0.85) : Theme.alpha(Theme.bgDark, 0.7)
                    border.width: 1
                    border.color: entry.critical ? Theme.alpha(Theme.signal, 0.8) : Theme.alpha(Theme.border, 0.9)
                }
                Rectangle {
                    x: 0; y: 8; width: 2; height: parent.height - 16
                    color: entry.critical ? Theme.signal : Theme.alpha(Theme.brass, 0.7)
                }
                HoverHandler { id: hover }
                TapHandler {
                    onTapped: {
                        const def = entry.modelData.actions.find(a => a.identifier === "default");
                        if (def) { def.invoke(); DeckState.open = false; }
                    }
                }

                Row {
                    id: body
                    x: 12
                    y: 9
                    width: parent.width - 24
                    spacing: 10

                    Item {
                        width: 28
                        height: 28
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 14
                            color: Theme.bgDark
                            visible: entry.iconSrc !== ""
                            IconImage { anchors.fill: parent; anchors.margins: 3; source: entry.iconSrc }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.alpha(Theme.brass, 0.6)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: entry.iconSrc === ""
                            text: "\u{f009a}"
                            color: Theme.brass
                            font.family: Theme.fontData
                            font.pixelSize: 13
                        }
                    }
                    Column {
                        width: parent.width - 28 - 10 - 22
                        spacing: 2
                        Item {
                            width: parent.width
                            height: app.implicitHeight
                            Text {
                                id: app
                                width: parent.width - when.width - 8
                                elide: Text.ElideRight
                                text: (entry.modelData.appName || "transmission").toLowerCase()
                                color: entry.critical ? Theme.signal : Theme.brass
                                font.family: Theme.fontLabel
                                font.pixelSize: Theme.labelSize - 1
                                font.capitalization: Font.SmallCaps
                                font.letterSpacing: Theme.labelSpacing
                                font.weight: Font.DemiBold
                            }
                            Text {
                                id: when
                                anchors.right: parent.right
                                text: root.ago(entry.modelData.id)
                                color: Theme.dim
                                font.family: Theme.fontData
                                font.pixelSize: Theme.dataSizeSmall
                            }
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: root.plain(entry.modelData.summary)
                            color: Theme.fg
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            text: root.plain(entry.modelData.body)
                            color: Theme.phosphor
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall + 1
                        }
                    }
                    Text {
                        width: 22
                        text: "\u{f0156}"
                        color: closeMouse.containsMouse ? Theme.signal : Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: 14
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: entry.modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}
