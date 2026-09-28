import QtQuick
import "../theme"

// A card: the slightly lighter surface Settings lays its rows on, 8 px corners, a hairline edge.
Rectangle {
    radius: Theme.radiusLarge
    color: Theme.card
    border.width: 1
    border.color: Theme.cardStroke
}
