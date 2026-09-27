import QtQuick
import QtQuick.Layouts

// Rounded section card with a small caps title and optional trailing text
Rectangle {
    id: card

    property string title
    property string trailing
    property color trailingColor: Theme.accent
    property int spacing: 12
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
            visible: card.title !== "" || card.trailing !== ""

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
                color: card.trailingColor
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            // Stretch even when no child does, so centered children center in the card
            Layout.maximumWidth: Number.POSITIVE_INFINITY
            spacing: card.spacing
        }
    }
}
