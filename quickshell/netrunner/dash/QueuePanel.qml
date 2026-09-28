import QtQuick
import "../theme"
import "../widgets"
import "../services"

// QUEUE // DAILY GIGS 依頼: today's list (services/Queue.qml). A segment per gig along the top,
// lit as they're cleared; each row a box to tick, the gig, its tag and ACTIVE / NEXT / DONE.
// EDIT shows a field to add one ("text | tag") and an × on each row to drop it.
Panel {
    id: root

    title: "QUEUE  //  DAILY GIGS"
    jp: "依頼"
    trailing: ""

    property bool editing: false

    Item {
        anchors.fill: parent

        // header right: 1/3 CLEARED and EDIT (sits in the panel's header line)
        Row {
            anchors.right: parent.right
            y: -root.contentTop + 7
            spacing: 12
            Label { anchors.verticalCenter: parent.verticalCenter; text: Queue.cleared + "/" + Queue.total + " CLEARED" }
            Btn { text: root.editing ? "DONE" : "EDIT"; on: root.editing; onClicked: root.editing = !root.editing }
        }

        Column {
            width: parent.width
            spacing: 6

            // progress: one segment per gig
            Row {
                width: parent.width
                spacing: 4
                Repeater {
                    model: Queue.total
                    Rectangle {
                        required property int index
                        width: (parent.width - (Queue.total - 1) * 4) / Math.max(1, Queue.total)
                        height: 3
                        color: Queue.gigs[index]?.done ? Theme.cyan : Theme.alpha(Theme.dim, 0.35)
                    }
                }
            }
            Item { width: 1; height: 6 }

            Repeater {
                model: Queue.gigs
                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string state_: Queue.status(index)
                    width: parent.width
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        visible: row.state_ === "active"
                        color: Theme.alpha(Theme.red, 0.1)
                        Rectangle { width: 2; height: parent.height; color: Theme.red }
                    }
                    // the box
                    Rectangle {
                        id: box
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14; height: 14
                        color: row.modelData.done ? Theme.alpha(Theme.dim, 0.3) : "transparent"
                        border.width: 1
                        border.color: row.state_ === "active" ? Theme.red : Theme.dim
                        Text { anchors.centerIn: parent; visible: row.modelData.done; text: "✓"; color: Theme.fg; font.pixelSize: 11 }
                    }
                    Text {
                        x: box.x + box.width + 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 200
                        elide: Text.ElideRight
                        text: row.modelData.text
                        color: row.modelData.done ? Theme.dim : Theme.fg
                        font.family: Theme.sans
                        font.pixelSize: Theme.data + 1
                        font.strikeout: row.modelData.done
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 16
                        Label { text: row.modelData.tag }
                        Label {
                            width: 56
                            horizontalAlignment: Text.AlignRight
                            text: row.state_.toUpperCase()
                            color: row.state_ === "active" ? Theme.red : row.state_ === "done" ? Theme.dim : Theme.fg
                            strong: row.state_ !== "done"
                        }
                        Text {
                            visible: root.editing
                            text: "✕"
                            color: Theme.red
                            font.pixelSize: 12
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Queue.remove(row.index) }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: root.editing ? 40 : 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Queue.toggle(row.index)
                    }
                }
            }

            Field {
                visible: root.editing
                width: parent.width
                placeholder: "new gig  |  tag   (enter to add)"
                onAccepted: {
                    const p = text.split("|");
                    Queue.add(p[0], p[1] ?? "");
                    text = "";
                }
            }
        }
    }
}
