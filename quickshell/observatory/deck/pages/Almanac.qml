import QtQuick
import Quickshell
import "../../theme"
import "../../services"
import ".."

// Almanac: the month (scroll or ‹ › to change it, today in brass), tonight's moon, and the weather:
// now, the next hours, the week, sunrise and sunset. Weather: services/Weather.qml (Open-Meteo).
Column {
    id: root

    spacing: 22
    Component.onCompleted: Weather.refreshIfStale()

    SystemClock { id: clock; precision: SystemClock.Minutes }

    property int offset: 0      // months from this one
    readonly property date shown: {
        const d = clock.date;
        return new Date(d.getFullYear(), d.getMonth() + offset, 1);
    }

    // Moon phase, 0 = new .. 0.5 = full .. 1 = new (mean synodic month from a known new moon)
    function moonPhase(d) {
        const days = (d.getTime() - Date.UTC(2000, 0, 6, 18, 14)) / 86400000;
        const p = (days / 29.530588853) % 1;
        return p < 0 ? p + 1 : p;
    }
    function moonName(p) {
        const names = ["new moon", "waxing crescent", "first quarter", "waxing gibbous",
                       "full moon", "waning gibbous", "last quarter", "waning crescent"];
        return names[Math.round(p * 8) % 8];
    }
    function temp(t) { return Math.round(t) + "°"; }

    // ---------------------------------------------------------------- calendar
    Section {
        title: Qt.formatDate(root.shown, "MMMM yyyy").toLowerCase()
        trailing: root.offset !== 0 ? "" : Qt.formatDate(clock.date, "dddd d").toLowerCase()

        Item {
            width: parent.width
            height: grid.height + 34

            Row {
                id: nav
                anchors.right: parent.right
                spacing: 6
                Link { text: "‹"; onClicked: root.offset-- }
                Link { text: "today"; visible: root.offset !== 0; onClicked: root.offset = 0 }
                Link { text: "›"; onClicked: root.offset++ }
            }

            Grid {
                id: grid
                y: 36
                width: parent.width
                columns: 7
                readonly property real cell: width / 7
                readonly property int lead: (new Date(root.shown.getFullYear(), root.shown.getMonth(), 1).getDay() + 6) % 7
                readonly property int days: new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 0).getDate()

                Repeater {
                    model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
                    Text {
                        required property string modelData
                        width: grid.cell
                        height: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.brass
                        font.family: Theme.fontLabel
                        font.pixelSize: Theme.labelSize - 1
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: Theme.labelSpacing
                        font.weight: Font.DemiBold
                    }
                }
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property int day: index - grid.lead + 1
                        readonly property bool inMonth: day >= 1 && day <= grid.days
                        readonly property bool today: inMonth && root.offset === 0 && day === clock.date.getDate()
                        readonly property real phase: root.moonPhase(new Date(root.shown.getFullYear(), root.shown.getMonth(), day, 21))
                        readonly property bool fullOrNew: inMonth && (Math.abs(phase - 0.5) < 0.017 || phase < 0.017 || phase > 0.983)
                        width: grid.cell
                        height: 34
                        visible: index < grid.lead + grid.days + (7 - (grid.lead + grid.days) % 7) % 7
                        Rectangle {
                            anchors.centerIn: parent
                            width: 30; height: 30; radius: 15
                            visible: parent.today
                            color: Theme.alpha(Theme.brassMuted, 0.9)
                            border.width: 1.2
                            border.color: Theme.brassBright
                        }
                        Text {
                            anchors.centerIn: parent
                            text: parent.inMonth ? parent.day : ""
                            color: parent.today ? Theme.starlight : (index % 7 >= 5 ? Theme.dim : Theme.fg)
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSize
                            font.weight: parent.today ? Font.DemiBold : Font.Normal
                        }
                        // full and new moons marked with a small dot
                        Rectangle {
                            visible: parent.fullOrNew
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: 4; height: 4; radius: 2
                            color: Math.abs(parent.phase - 0.5) < 0.1 ? Theme.starlight : "transparent"
                            border.width: 1
                            border.color: Theme.starlight
                        }
                    }
                }
            }
            WheelHandler {
                onWheel: e => root.offset += e.angleDelta.y > 0 ? -1 : 1
            }
        }
    }

    // ---------------------------------------------------------------- moon
    Section {
        title: "tonight's moon"
        trailing: Math.round((1 - Math.cos(2 * Math.PI * root.moonPhase(clock.date))) / 2 * 100) + "% lit"

        Item {
            width: parent.width
            height: 64
            Canvas {
                id: moon
                width: 56; height: 56
                anchors.verticalCenter: parent.verticalCenter
                readonly property real p: root.moonPhase(clock.date)
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const r = 24, cx = 28, cy = 28;
                    ctx.fillStyle = Theme.alpha(Theme.bg, 1);
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2 * Math.PI); ctx.fill();
                    // lit part: a half disc plus/minus an ellipse (terminator)
                    const k = Math.cos(2 * Math.PI * p);            // 1 new .. -1 full
                    const waxing = p < 0.5;
                    ctx.fillStyle = Theme.starlight;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
                    ctx.save();
                    ctx.translate(cx, cy);
                    ctx.scale(Math.abs(k), 1);
                    ctx.arc(0, 0, r, Math.PI / 2, -Math.PI / 2, (k > 0) === waxing);
                    ctx.restore();
                    ctx.closePath();
                    ctx.fill();
                    ctx.strokeStyle = Theme.alpha(Theme.brass, 0.7);
                    ctx.lineWidth = 1;
                    ctx.beginPath(); ctx.arc(cx, cy, r + 3, 0, 2 * Math.PI); ctx.stroke();
                }
            }
            Column {
                anchors.left: moon.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: root.moonName(moon.p)
                    color: Theme.brassBright
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSizeLarge + 2
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "day " + Math.floor(moon.p * 29.53) + " of 29.5"
                    color: Theme.dim
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
            }
        }
    }

    // ---------------------------------------------------------------- weather
    Section {
        title: "weather" + (Weather.place ? "  ·  " + Weather.place.toLowerCase() : "")
        trailing: Weather.loading ? "fetching…" : Weather.ready ? "updated " + Qt.formatTime(Weather.updated, "HH:mm") : ""

        Text {
            visible: Weather.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            text: Weather.error
            color: Theme.signal
            font.family: Theme.fontData
            font.pixelSize: Theme.dataSizeSmall
        }

        // Now
        Item {
            visible: Weather.ready
            width: parent.width
            height: 76
            Text {
                id: nowIcon
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.isDay) : ""
                color: Theme.brass
                font.family: Theme.fontData
                font.pixelSize: 48
            }
            Column {
                anchors.left: nowIcon.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: Weather.ready ? root.temp(Weather.current.temp) : ""
                    color: Theme.starlight
                    font.family: Theme.fontData
                    font.pixelSize: 32
                    font.weight: Font.Light
                }
                Text {
                    text: Weather.ready ? Weather.describe(Weather.current.code).toLowerCase() : ""
                    color: Theme.brass
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize + 1
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                }
            }
            Grid {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                columns: 1
                rowSpacing: 2
                Repeater {
                    model: Weather.ready ? [
                        ["feels", root.temp(Weather.current.feels)],
                        ["humidity", Weather.current.humidity + "%"],
                        ["wind", Math.round(Weather.current.wind) + " " + Weather.windLabel],
                        ["sun", Qt.formatTime(Weather.sunrise, "HH:mm") + " – " + Qt.formatTime(Weather.sunset, "HH:mm")],
                    ] : []
                    Text {
                        required property var modelData
                        required property int index
                        text: modelData[0]
                        color: Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                        Text {
                            x: 70
                            text: parent.modelData[1]
                            color: Theme.fg
                            font.family: Theme.fontData
                            font.pixelSize: Theme.dataSizeSmall
                        }
                        width: 180
                    }
                }
            }
        }

        // Next hours
        Row {
            visible: Weather.ready
            width: parent.width
            Repeater {
                model: Weather.hourly.filter((_, i) => i % 2 === 0).slice(0, 8)
                Column {
                    required property var modelData
                    width: parent.width / 8
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(modelData.time, "HH")
                        color: Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.icon(modelData.code, modelData.isDay)
                        color: Theme.brass
                        font.family: Theme.fontData
                        font.pixelSize: 18
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.temp(modelData.temp)
                        color: Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall + 1
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.pop > 0 ? modelData.pop + "%" : " "
                        color: Theme.phosphor
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall - 1
                    }
                }
            }
        }

        // The week
        Repeater {
            model: Weather.daily
            Item {
                required property var modelData
                required property int index
                width: parent.width
                height: 26
                readonly property real lo: Math.min(...Weather.daily.map(d => d.min))
                readonly property real hi: Math.max(...Weather.daily.map(d => d.max))
                Text {
                    width: 70
                    anchors.verticalCenter: parent.verticalCenter
                    text: index === 0 ? "today" : Qt.formatDate(modelData.date, "ddd").toLowerCase()
                    color: index === 0 ? Theme.brassBright : Theme.fg
                    font.family: Theme.fontLabel
                    font.pixelSize: Theme.labelSize
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: Theme.labelSpacing
                    font.weight: Font.DemiBold
                }
                Text {
                    x: 74
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.icon(modelData.code, true)
                    color: Theme.brass
                    font.family: Theme.fontData
                    font.pixelSize: 16
                }
                Text {
                    x: 104
                    width: 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.pop > 0 ? modelData.pop + "%" : ""
                    color: Theme.phosphor
                    font.family: Theme.fontData
                    font.pixelSize: Theme.dataSizeSmall
                }
                // temperature range bar on the week's scale
                Item {
                    x: 150
                    width: parent.width - 150
                    height: parent.height
                    readonly property real span: Math.max(1, parent.hi - parent.lo)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.temp(modelData.min)
                        color: Theme.dim
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                    }
                    Rectangle {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        height: 1
                        color: Theme.alpha(Theme.brassDeep, 0.8)
                        Rectangle {
                            x: (modelData.min - parent.parent.parent.lo) / parent.parent.span * parent.width
                            width: Math.max(4, (modelData.max - modelData.min) / parent.parent.span * parent.width)
                            height: 3
                            y: -1
                            radius: 1.5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.phosphor }
                                GradientStop { position: 1; color: Theme.brassBright }
                            }
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.temp(modelData.max)
                        color: Theme.fg
                        font.family: Theme.fontData
                        font.pixelSize: Theme.dataSizeSmall
                    }
                }
            }
        }
    }
}
