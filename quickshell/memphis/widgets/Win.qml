import QtQuick
import "../theme"

// A 98 window: a raised frame, the caption with its left-to-right gradient (navy to blue while
// active, greys while not), the small icon, bold title and caption buttons; an optional menu bar
// and status bar. Drag it by the caption. Children go in the client area.
//
// The shell's windows (Control Panel, Properties sheets, Run…) are items inside a layer surface
// (see desk/DeskLayer.qml), so "active" is just the one raised last.
FocusScope {
    id: root

    property string title: ""
    property string icon: ""
    property bool active: true
    property bool closable: true
    property bool helpButton: false
    property bool minButton: false
    property var menus: []                  // menu bar: [{ title, items: () => [menu items] }]
    property string status: ""              // status bar text ("" = no status bar)
    property var statusParts: []            // extra status panes on the right
    property bool dialog: true              // dialog frame (no resize handle)
    default property alias content: client.data
    readonly property alias client: client

    signal closeRequested()
    signal helpRequested()
    signal minRequested()
    signal pressed()                        // any click inside: raise me
    signal dragBy(real dx, real dy)         // the caption is being dragged: the host moves me
    signal menuRequested(var menu, real x, real y)

    Keys.onEscapePressed: if (closable) closeRequested()

    Bevel {
        anchors.fill: parent
        kind: "raised"
        fill: Theme.face
    }
    // any click raises the window (without stealing it from the children)
    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: root.pressed()
    }

    // ---------------------------------------------------------------- caption
    Rectangle {
        id: caption
        x: Theme.frame - 1
        y: Theme.frame - 1
        width: parent.width - (Theme.frame - 1) * 2
        height: Theme.titleHeight
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.active ? Theme.title : Theme.inactiveTitle }
            GradientStop { position: 1; color: root.active ? Theme.title2 : Theme.inactiveTitle2 }
        }

        Icon {
            id: capIcon
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: Theme.icon - 2
        }
        Txt {
            x: capIcon.visible ? capIcon.width + 8 : 5
            width: capButtons.x - x - 4
            height: parent.height
            elide: Text.ElideRight
            text: root.title
            bold: true
            color: root.active ? Theme.titleText : Theme.inactiveTitleText
        }

        MouseArea {
            anchors.fill: parent
            property point grab
            onPressed: e => { root.pressed(); grab = Qt.point(e.x, e.y); }
            onPositionChanged: e => { if (pressed) root.dragBy(e.x - grab.x, e.y - grab.y); }
        }

        Row {
            id: capButtons
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            CapBtn { visible: root.helpButton; glyph: "help"; onClicked: root.helpRequested() }
            CapBtn { visible: root.minButton; glyph: "min"; onClicked: root.minRequested() }
            Item { width: 2; height: 1; visible: root.helpButton || root.minButton }
            CapBtn { visible: root.closable || true; enabled: root.closable; glyph: "close"; onClicked: root.closeRequested() }
        }
    }

    // ---------------------------------------------------------------- menu bar
    Row {
        id: menuBar
        visible: root.menus.length > 0
        x: Theme.frame
        y: caption.y + caption.height + 1
        height: visible ? Theme.menuItem - 2 : 0
        Repeater {
            model: root.menus
            Item {
                id: mItem
                required property var modelData
                width: mLabel.implicitWidth + 16
                height: menuBar.height
                Bevel { anchors.fill: parent; kind: mMouse.pressed ? "status" : mMouse.containsMouse ? "thin" : "none" }
                Txt { id: mLabel; anchors.centerIn: parent; text: mItem.modelData.title }
                MouseArea {
                    id: mMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        const p = mItem.mapToItem(null, 0, mItem.height);
                        root.menuRequested(mItem.modelData, p.x, p.y);
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- client area
    Item {
        id: client
        x: Theme.frame
        y: caption.y + caption.height + 2 + (menuBar.visible ? menuBar.height + 2 : 0)
        width: parent.width - Theme.frame * 2
        height: parent.height - y - Theme.frame - (statusBar.visible ? statusBar.height + 2 : 0)
    }

    // ---------------------------------------------------------------- status bar
    Row {
        id: statusBar
        visible: root.status !== "" || root.statusParts.length > 0
        x: Theme.frame
        y: parent.height - Theme.frame - height
        width: parent.width - Theme.frame * 2
        height: visible ? Theme.menuItem - 4 : 0
        spacing: 2
        Bevel {
            kind: "status"
            width: statusBar.width - partsRow.width - (root.statusParts.length ? 2 : 0)
            height: statusBar.height
            Txt { x: 4; width: parent.width - 8; height: parent.height; elide: Text.ElideRight; text: root.status }
        }
        Row {
            id: partsRow
            spacing: 2
            Repeater {
                model: root.statusParts
                Bevel {
                    required property var modelData
                    kind: "status"
                    width: Math.max(80, pl.implicitWidth + 12)
                    height: statusBar.height
                    Txt { id: pl; x: 6; height: parent.height; text: modelData }
                }
            }
        }
    }

    component CapBtn: Btn {
        width: Theme.titleButton
        height: Theme.titleButton - 2
        implicitWidth: Theme.titleButton
        implicitHeight: Theme.titleButton - 2
        padding: 0
        activeFocusOnTab: false
    }
}
