import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import "../theme"
import "../widgets"
import "../services"
import "../settings"

// The notification centre (Windows + N), two cards down the right: your notifications (newest
// first, Clear all, the Do not disturb bell), and the calendar with Focus under it (a focus
// session is the shared focus timer: pick the minutes, Focus starts it).
Item {
    id: root

    required property string screenName
    property bool active: false
    property bool calendarOpen: true
    onActiveChanged: if (active) { Notifs.unread = 0; offset = 0; }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    property int offset: 0                  // months from this one
    readonly property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth() + offset, 1)

    // ---------------------------------------------------------------- notifications
    Acrylic {
        id: notes
        width: parent.width
        height: parent.height - cal.height - 12

        Txt { x: 20; y: 16; text: "Notifications"; strong: true }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 12
            y: 10
            spacing: 4
            Btn {
                visible: Notifs.history.length > 0
                kind: "subtle"; text: "Clear all"; padding: 8; height: 30
                onClicked: Notifs.clearAll()
            }
            Btn {
                id: bellBtn
                kind: "subtle"; width: 30; height: 30
                glyph: Notifs.dnd ? "" : ""
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
                Tip { target: bellBtn; hovered: bellBtn.hovered; text: Notifs.dnd ? "Do not disturb is on" : "Do not disturb" }
            }
        }
        Txt {
            visible: Notifs.history.length === 0
            anchors.centerIn: parent
            text: Notifs.dnd ? "Do not disturb is on\nYou'll only see urgent notifications" : "No new notifications"
            horizontalAlignment: Text.AlignHCenter
            level: 2
        }
        ListView {
            id: list
            x: 12; y: 52
            width: parent.width - 24
            height: parent.height - y - 12
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.history
            delegate: Card {
                id: card
                required property var modelData
                readonly property var n: modelData
                width: list.width
                height: body.implicitHeight + 24
                color: cm.containsMouse ? Theme.cardHover : Theme.card
                MouseArea {
                    id: cm
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        const def = (card.n.actions ?? []).find(a => a.identifier === "default");
                        if (def) { def.invoke(); Flyouts.close(); }
                    }
                }
                Column {
                    id: body
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 6
                    Item {
                        width: parent.width; height: 20
                        AppIcon { size: 16; anchors.verticalCenter: parent.verticalCenter; name: card.n.appIcon || (card.n.appName ?? "").toLowerCase() }
                        Txt { x: 24; width: parent.width - 80; height: parent.height; text: card.n.appName || "Notification"; size: Theme.caption; level: 2 }
                        Txt {
                            anchors.right: parent.right
                            visible: !cm.containsMouse && !closeBtn.hovered
                            height: parent.height
                            size: Theme.caption; level: 2
                            text: { const t = Notifs.times[card.n.id]; return t ? Qt.formatTime(new Date(t), "h:mm AP") : ""; }
                        }
                        Btn {
                            id: closeBtn
                            visible: cm.containsMouse || hovered
                            anchors.right: parent.right
                            kind: "subtle"; glyph: ""; glyphSize: 10; width: 24; height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: card.n.dismiss()
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        ClippingRectangle {
                            visible: (card.n.image ?? "") !== ""
                            width: 48; height: 48; radius: Theme.radius
                            color: "transparent"
                            Image { anchors.fill: parent; source: card.n.image ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 96 }
                        }
                        Column {
                            width: parent.width - ((card.n.image ?? "") !== "" ? 58 : 0)
                            Txt { width: parent.width; text: card.n.summary ?? ""; strong: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
                            Txt { width: parent.width; text: card.n.body ?? ""; level: 2; wrapMode: Text.Wrap; maximumLineCount: 4; textFormat: Text.StyledText; size: Theme.caption + 1 }
                        }
                    }
                    Row {
                        visible: (card.n.actions ?? []).filter(a => a.identifier !== "default").length > 0
                        spacing: 8
                        Repeater {
                            model: (card.n.actions ?? []).filter(a => a.identifier !== "default")
                            Btn { required property var modelData; text: modelData.text; onClicked: modelData.invoke() }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- calendar + focus
    Acrylic {
        id: cal
        y: parent.height - height
        width: parent.width
        height: 56 + (root.calendarOpen ? 332 : 0) + 64
        Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        clip: true

        Txt { x: 20; y: 0; height: 56; text: Qt.formatDate(clock.date, "dddd, MMMM d"); strong: true }
        Btn {
            anchors.right: parent.right; anchors.rightMargin: 12
            y: 12
            kind: "subtle"; width: 32; height: 32
            glyph: root.calendarOpen ? "" : ""; glyphSize: 12
            onClicked: root.calendarOpen = !root.calendarOpen
        }
        Rectangle { y: 56; width: parent.width; height: 1; color: Theme.divider }

        Item {
            y: 57
            width: parent.width
            height: 332
            visible: root.calendarOpen
            Txt { x: 20; y: 8; height: 32; text: Qt.formatDate(root.shown, "MMMM yyyy"); strong: true }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12
                y: 8
                Btn { kind: "subtle"; glyph: ""; glyphSize: 12; width: 32; onClicked: root.offset-- }
                Btn { kind: "subtle"; glyph: ""; glyphSize: 12; width: 32; onClicked: root.offset++ }
            }
            Grid {
                x: (parent.width - width) / 2
                y: 48
                columns: 7
                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    Txt { required property string modelData; width: 44; height: 36; horizontalAlignment: Text.AlignHCenter; text: modelData; size: Theme.caption }
                }
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property date d: new Date(root.shown.getFullYear(), root.shown.getMonth(), index - root.shown.getDay() + 1)
                        readonly property bool inMonth: d.getMonth() === root.shown.getMonth()
                        readonly property bool today: d.toDateString() === clock.date.toDateString()
                        width: 44; height: 40
                        Rectangle {
                            anchors.centerIn: parent
                            width: 36; height: 36; radius: 18
                            color: parent.today ? (dm.containsMouse ? Theme.accentHover : Theme.accent) : dm.containsMouse ? Theme.subtle : "transparent"
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: parent.d.getDate()
                            color: parent.today ? Theme.accentText : parent.inMonth ? Theme.text : Theme.text3
                            strong: parent.today
                        }
                        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }
        }

        // Focus: − 25 mins +   ▶ Focus
        Item {
            id: focus
            y: parent.height - 64
            width: parent.width
            height: 64
            Rectangle { width: parent.width; height: 1; color: Theme.divider }
            Row {
                visible: !FocusTimer.active
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Btn { kind: "subtle"; glyph: ""; width: 32; onClicked: { FocusTimer.setMode("timer"); FocusTimer.setTimerMins(FocusTimer.timerMins - 5); } }
                Txt { width: 72; height: 32; horizontalAlignment: Text.AlignHCenter; text: FocusTimer.timerMins + " mins" }
                Btn { kind: "subtle"; glyph: ""; width: 32; onClicked: { FocusTimer.setMode("timer"); FocusTimer.setTimerMins(FocusTimer.timerMins + 5); } }
            }
            Row {
                visible: FocusTimer.active
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Ring { width: 28; height: 28; value: 1 - FocusTimer.progress; track: Theme.subtle; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { text: FocusTimer.remainingText; strong: true }
                    Txt { text: FocusTimer.phaseLabel + (FocusTimer.running ? "" : " · paused"); size: Theme.caption; level: 2 }
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Btn {
                    visible: FocusTimer.active
                    kind: "subtle"; glyph: ""; width: 32
                    onClicked: FocusTimer.reset()
                }
                Btn {
                    kind: FocusTimer.active ? "standard" : "accent"
                    glyph: FocusTimer.running ? "" : ""
                    text: FocusTimer.running ? "Pause" : FocusTimer.active ? "Resume" : "Focus"
                    onClicked: { if (!FocusTimer.active && FocusTimer.mode !== "timer") FocusTimer.setMode("timer"); FocusTimer.toggle(); }
                }
            }
        }
    }
}
