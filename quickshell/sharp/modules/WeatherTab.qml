import QtQuick
import QtQuick.Layouts

// Current conditions, stats, hourly strip and 7-day forecast. Scrolls when the panel is short.
Flickable {
    id: root

    readonly property var cur: Weather.current

    function deg(t) {
        return Math.round(t) + "°";
    }

    // Moon phase, 0 = new .. 0.5 = full .. 1 = new (mean synodic month from a known new moon)
    function moonPhase(d) {
        const days = (d.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        const p = (days / 29.530588853) % 1;
        return p < 0 ? p + 1 : p;
    }
    function moonName(p) {
        const names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                       "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"];
        return names[Math.round(p * 8) % 8];
    }
    property date now: new Date()
    Timer { running: root.visible; repeat: true; interval: 600000; onTriggered: root.now = new Date() }

    // Loading / error state
    Column {
        anchors.centerIn: parent
        visible: !Weather.ready
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.icon(Weather.error ? 3 : 0)
            font.family: Theme.font
            font.pixelSize: 40
            color: Theme.border
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.error || "Loading weather…"
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.dim
        }

        Pill {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Weather.error !== ""
            label: "Retry"
            onClicked: Weather.refresh()
        }
    }

    contentHeight: content.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: content
        // At least the page height, so the footer stays at the bottom when everything fits
        width: root.width
        height: Math.max(root.height, implicitHeight)
        visible: Weather.ready
        spacing: 22

        // Hero
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "  " + (Weather.place || "Here").toUpperCase()
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    color: Theme.accent
                }

                Text {
                    text: root.cur ? root.deg(root.cur.temp) : ""
                    font.family: Theme.font
                    font.pixelSize: 64
                    font.bold: true
                    color: Theme.fg
                }

                Text {
                    text: root.cur ? Weather.describe(root.cur.code) : ""
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: Theme.fg
                }

                Text {
                    Layout.topMargin: 2
                    text: root.cur && Weather.daily.length
                        ? "Feels " + root.deg(root.cur.feels) + "  ·  H " + root.deg(Weather.daily[0].max) + "  L " + root.deg(Weather.daily[0].min)
                        : ""
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.dim
                }
            }

            // Big icon with a soft glow
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 120
                implicitHeight: 120

                Rectangle {
                    anchors.centerIn: parent
                    width: 104
                    height: 104
                    radius: 0
                    color: Theme.accentMuted
                    opacity: 0.18
                }

                Text {
                    anchors.centerIn: parent
                    text: root.cur ? Weather.icon(root.cur.code, root.cur.isDay) : ""
                    font.family: Theme.font
                    font.pixelSize: 72
                    color: Theme.accent
                }
            }
        }

        // Stat tiles
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StatTile {
                icon: String.fromCodePoint(0xF058E)
                value: root.cur ? root.cur.humidity + "%" : ""
                label: "Humidity"
            }
            StatTile {
                icon: String.fromCodePoint(0xF059D)
                value: root.cur ? Math.round(root.cur.wind) : ""
                label: Weather.windLabel
            }
            StatTile {
                icon: String.fromCodePoint(0xF059C)
                value: Qt.formatTime(Weather.sunrise, "HH:mm")
                label: "Sunrise"
            }
            StatTile {
                icon: String.fromCodePoint(0xF059B)
                value: Qt.formatTime(Weather.sunset, "HH:mm")
                label: "Sunset"
            }
        }

        // Hourly
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            SectionLabel { text: "Next 24 hours" }

            ListView {
                id: hours

                Layout.fillWidth: true
                implicitHeight: 96
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Weather.hourly

                // Mouse wheel scrolls sideways
                WheelHandler {
                    onWheel: event => hours.flick(event.angleDelta.y * 8, 0)
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool now: index === 0

                    width: 52
                    height: 96
                    radius: 0
                    color: now ? Theme.surface : Theme.bgDark
                    border.width: 1
                    border.color: now ? Theme.accent : Theme.border

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.now ? "Now" : Qt.formatTime(parent.parent.modelData.time, "HH")
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.bold: parent.parent.now
                            color: parent.parent.now ? Theme.accent : Theme.dim
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.icon(parent.parent.modelData.code, parent.parent.modelData.isDay)
                            font.family: Theme.font
                            font.pixelSize: 20
                            color: Theme.fg
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.deg(parent.parent.modelData.temp)
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.fg
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.pop >= 20 ? parent.parent.modelData.pop + "%" : " "
                            font.family: Theme.font
                            font.pixelSize: 10
                            color: Theme.accent
                        }
                    }
                }
            }
        }

        // 7-day
        ColumnLayout {
            id: week

            Layout.fillWidth: true
            spacing: 4

            readonly property real weekMin: Math.min(...Weather.daily.map(d => d.min))
            readonly property real weekMax: Math.max(...Weather.daily.map(d => d.max))

            SectionLabel {
                text: "7-day forecast"
                bottomPadding: 6
            }

            Repeater {
                id: days
                model: Weather.daily

                RowLayout {
                    id: dayRow

                    required property var modelData
                    required property int index
                    readonly property real span: Math.max(1, week.weekMax - week.weekMin)

                    Layout.fillWidth: true
                    implicitHeight: 34
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 52
                        text: dayRow.index === 0 ? "Today" : Qt.formatDate(dayRow.modelData.date, "ddd")
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: dayRow.index === 0
                        color: Theme.fg
                    }

                    Text {
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: Weather.icon(dayRow.modelData.code)
                        font.family: Theme.font
                        font.pixelSize: 18
                        color: Theme.fg
                    }

                    Text {
                        Layout.preferredWidth: 34
                        text: dayRow.modelData.pop >= 20 ? dayRow.modelData.pop + "%" : ""
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.accent
                    }

                    Text {
                        Layout.preferredWidth: 32
                        horizontalAlignment: Text.AlignRight
                        text: root.deg(dayRow.modelData.min)
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.dim
                    }

                    // Temperature range relative to the whole week
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 0
                        color: Theme.surface

                        Rectangle {
                            x: parent.width * (dayRow.modelData.min - week.weekMin) / dayRow.span
                            width: Math.max(6, parent.width * (dayRow.modelData.max - dayRow.modelData.min) / dayRow.span)
                            height: parent.height
                            radius: 0
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.accentMuted }
                                GradientStop { position: 1; color: Theme.accent }
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: 32
                        text: root.deg(dayRow.modelData.max)
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.fg
                    }
                }
            }
        }

        // Tonight's moon
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            SectionLabel { text: "Moon" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Canvas {
                    id: moon
                    implicitWidth: 48
                    implicitHeight: 48
                    readonly property real p: root.moonPhase(root.now)
                    onPChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const r = 20, cx = 24, cy = 24;
                        ctx.fillStyle = Theme.surface;
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill();
                        // lit part: a half disc plus or minus an ellipse (the terminator)
                        const k = Math.cos(2 * Math.PI * p);        // 1 new .. -1 full
                        const waxing = p < 0.5;
                        ctx.fillStyle = Theme.fg;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
                        ctx.save();
                        ctx.translate(cx, cy);
                        ctx.scale(Math.abs(k), 1);
                        ctx.arc(0, 0, r, Math.PI / 2, -Math.PI / 2, (k > 0) === waxing);
                        ctx.restore();
                        ctx.closePath();
                        ctx.fill();
                    }
                    Connections {
                        target: Theme
                        function onPaletteChanged() { moon.requestPaint(); }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.moonName(moon.p)
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.fg
                    }

                    Text {
                        text: Math.round((1 - Math.cos(2 * Math.PI * moon.p)) / 2 * 100) + "% lit  ·  day "
                              + Math.floor(moon.p * 29.53) + " of 29.5"
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.dim
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Footer
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Updated " + Qt.formatTime(Weather.updated, "HH:mm") + "  ·  Open-Meteo"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.border
            }

            Pill {
                label: Weather.loading ? "Refreshing…" : "Refresh"
                onClicked: Weather.refresh()
            }
        }
    }

    component SectionLabel: Text {
        font.family: Theme.font
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 2
        font.capitalization: Font.AllUppercase
        color: Theme.dim
    }

    component StatTile: Rectangle {
        id: tile

        property string icon
        property string value
        property string label

        Layout.fillWidth: true
        implicitHeight: 78
        radius: 0
        color: Theme.surface

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.icon
                font.family: Theme.font
                font.pixelSize: 18
                color: Theme.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.value
                font.family: Theme.font
                font.pixelSize: 14
                font.bold: true
                color: Theme.fg
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                font.family: Theme.font
                font.pixelSize: 10
                color: Theme.dim
            }
        }
    }

    component Pill: Rectangle {
        property string label
        signal clicked

        implicitWidth: pillText.implicitWidth + 20
        implicitHeight: 24
        radius: 0
        color: pillMouse.containsMouse ? Theme.surface : "transparent"
        border.width: 1
        border.color: pillMouse.containsMouse ? Theme.accent : Theme.border

        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            font.family: Theme.font
            font.pixelSize: 11
            color: pillMouse.containsMouse ? Theme.accent : Theme.dim
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
