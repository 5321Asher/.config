import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"
import "../widgets"
import "pages"

// The Settings app's window: a real window (it floats, has a taskbar button, and SUPER + C closes it)
// with Mica behind it, Windows' own title bar (drag it; minimise, maximise, close at the right),
// the account and "Find a setting" above the left pane, and the page with its breadcrumb title.
FloatingWindow {
    id: win

    visible: SettingsApp.isOpen
    title: "Settings"
    // opaque, like every other window (a see-through Settings showed the windows behind it)
    color: Theme.mica
    implicitWidth: 1100
    implicitHeight: 740
    minimumSize: Qt.size(640, 480)
    onVisibleChanged: if (!visible) SettingsApp.isOpen = false

    readonly property bool compact: width < 860

    // the caption buttons do exactly what every other window's do (hyprbars runs the same script on the
    // window under the pointer): maximise on top of everything / restore down, minimise to the taskbar
    function caption(cmd) { Quickshell.execDetached([Quickshell.shellDir + "/scripts/caption.sh", cmd]); }
    readonly property string section: SettingsApp.section(SettingsApp.page)

    // ---------------------------------------------------------------- title bar
    Item {
        id: titleBar
        width: parent.width
        height: 48
        MouseArea {
            anchors.fill: parent
            onPressed: win.startSystemMove()
            onDoubleClicked: win.caption("max")
        }
        Btn {
            visible: SettingsApp.history.length > 0
            x: 8; y: 8
            kind: "subtle"; glyph: ""; glyphSize: 12; width: 40; height: 32
            onClicked: SettingsApp.back()
        }
        Row {
            x: SettingsApp.history.length > 0 ? 56 : 16
            height: 48
            spacing: 12
            Glyph { anchors.verticalCenter: parent.verticalCenter; g: ""; size: 14; color: Theme.accentLink }
            Txt { anchors.verticalCenter: parent.verticalCenter; text: "Settings"; size: Theme.caption }
        }
        Row {
            anchors.right: parent.right
            WinButton { g: ""; onClicked: win.caption("min") }
            WinButton { g: ""; onClicked: win.caption("max") }
            WinButton { g: ""; close: true; onClicked: SettingsApp.close() }
        }
    }

    // ---------------------------------------------------------------- left pane
    Item {
        id: navPane
        y: titleBar.height
        width: win.compact ? 64 : Theme.settingsNav
        height: parent.height - y

        Row {
            visible: !win.compact
            x: 16; y: 4
            spacing: 14
            Avatar { size: 64 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Txt { text: accountName.name || (Quickshell.env("USER") ?? ""); strong: true }
                Txt { text: "Local Account"; size: Theme.caption; level: 2 }
            }
        }
        AccountName { id: accountName }
        Field {
            id: find
            visible: !win.compact
            x: 16; y: 88
            width: parent.width - 32
            placeholder: "Find a setting"
            glyph: ""
            onAccepted: {
                const q = text.trim().toLowerCase();
                const hit = SettingsApp.index.find(s => (s.title + " " + s.keywords).toLowerCase().includes(q));
                if (hit) { SettingsApp.go(hit.id); text = ""; }
            }
        }
        Column {
            y: win.compact ? 8 : 136
            x: 8
            width: parent.width - 16
            spacing: 2
            Repeater {
                model: SettingsApp.nav
                Item {
                    id: navItem
                    required property string modelData
                    readonly property bool current: win.section === modelData
                    width: parent.width
                    height: 38
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: nm.pressed ? Theme.subtle2 : navItem.current || nm.containsMouse ? Theme.subtle : "transparent"
                    }
                    Rectangle {
                        visible: navItem.current
                        y: 11; width: 3; height: 16; radius: 1.5
                        color: Theme.accent
                    }
                    Glyph { x: 16; anchors.verticalCenter: parent.verticalCenter; g: SettingsApp.glyph(navItem.modelData); size: 16; color: navItem.current ? Theme.accentLink : Theme.text }
                    Txt { visible: !win.compact; x: 48; height: parent.height; text: SettingsApp.title(navItem.modelData) }
                    MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true; onClicked: SettingsApp.go(navItem.modelData) }
                }
            }
        }
    }

    // ---------------------------------------------------------------- the page
    Item {
        id: content
        x: navPane.width + 8
        y: titleBar.height
        width: parent.width - x
        height: parent.height - y

        // the breadcrumb: System  >  Display
        Row {
            id: crumbs
            x: 28; y: 2
            height: 52
            spacing: 12
            readonly property var chain: { const c = []; let p = SettingsApp.page; while (p) { c.unshift(p); p = SettingsApp.parentOf(p); } return c; }
            Repeater {
                model: crumbs.chain
                Row {
                    id: crumb
                    required property string modelData
                    required property int index
                    readonly property bool last: index === crumbs.chain.length - 1
                    spacing: 12
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        text: SettingsApp.title(crumb.modelData)
                        size: Theme.title
                        strong: true
                        color: crumb.last ? Theme.text : cm.containsMouse ? Theme.text : Theme.text2
                        MouseArea { id: cm; anchors.fill: parent; enabled: !crumb.last; hoverEnabled: true; onClicked: SettingsApp.go(crumb.modelData) }
                    }
                    Glyph { visible: !crumb.last; anchors.verticalCenter: parent.verticalCenter; g: ""; size: 14; color: Theme.text2 }
                }
            }
        }

        Scroll {
            id: scroll
            y: crumbs.y + crumbs.height + 12
            width: parent.width
            height: parent.height - y
            Item {
                width: scroll.width
                height: loader.item ? loader.item.implicitHeight + 40 : 0
                Loader {
                    id: loader
                    x: 28
                    width: Math.min(1000, scroll.width - 56)
                    sourceComponent: pageComponents[SettingsApp.page] ?? homePage
                    onLoaded: scroll.contentY = 0
                }
            }
        }
    }

    // pages by id (as types, so live reload sees edits)
    readonly property var pageComponents: ({
        home: homePage, system: systemPage, display: displayPage, sound: soundPage, notifications: notificationsPage,
        focus: focusPage, power: powerPage, storage: storagePage, performance: performancePage, about: aboutPage,
        bluetooth: bluetoothPage, network: networkPage, vpn: vpnPage, personalization: personalizationPage,
        background: backgroundPage, themes: themesPage, lighting: lightingPage, apps: appsPage, accounts: accountsPage,
        time: timePage, security: securityPage, update: updatePage,
    })
    Component { id: homePage; HomePage {} }
    Component { id: systemPage; SystemPage {} }
    Component { id: displayPage; DisplayPage {} }
    Component { id: soundPage; SoundPage {} }
    Component { id: notificationsPage; NotificationsPage {} }
    Component { id: focusPage; FocusPage {} }
    Component { id: powerPage; PowerPage {} }
    Component { id: storagePage; StoragePage {} }
    Component { id: performancePage; PerformancePage {} }
    Component { id: aboutPage; AboutPage {} }
    Component { id: bluetoothPage; BluetoothPage {} }
    Component { id: networkPage; NetworkPage {} }
    Component { id: vpnPage; VpnPage {} }
    Component { id: personalizationPage; PersonalizationPage {} }
    Component { id: backgroundPage; BackgroundPage {} }
    Component { id: themesPage; ThemesPage {} }
    Component { id: lightingPage; LightingPage {} }
    Component { id: appsPage; AppsPage {} }
    Component { id: accountsPage; AccountsPage {} }
    Component { id: timePage; TimePage {} }
    Component { id: securityPage; SecurityPage {} }
    Component { id: updatePage; UpdatePage {} }

    // a caption button: 46 x 32, close goes red
    component WinButton: Item {
        id: wb
        property string g
        property bool close: false
        signal clicked()
        width: 46; height: 32
        Rectangle {
            anchors.fill: parent
            color: wm.containsMouse ? (wb.close ? Theme.closeRed : Theme.subtle) : "transparent"
            topRightRadius: wb.close ? Theme.radiusLarge : 0
        }
        Glyph { anchors.centerIn: parent; g: wb.g; size: 10; color: wb.close && wm.containsMouse ? "#ffffff" : Theme.text }
        MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; onClicked: wb.clicked() }
    }
}
