pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../menus"

// Tray apps' menus (DBus menus) as ordinary menu cascades: each level is read through its own
// QsMenuOpener, which stays alive while the menu is open.
Singleton {
    id: root

    property var openers: []

    // A menu-items loader for a menu handle (the app's menu, or one of its submenus)
    function loader(handle) {
        return done => {
            const o = openerComp.createObject(root, { menu: handle, done: done });
            openers = openers.concat([o]);
        };
    }

    function show(item, screenName, x, y) {
        if (!item?.hasMenu) return;
        Menus.show(screenName, "tray", loader(item.menu), x, y, { up: false });
    }

    function convert(children) {
        return children.map(e => e.isSeparator ? { sep: true } : ({
            text: (e.text ?? "").replace(/_(?=\w)/, ""),
            icon: e.icon ?? "",
            enabled: e.enabled,
            check: e.buttonType === QsMenuButtonType.CheckBox && e.checkState === Qt.Checked,
            radio: e.buttonType === QsMenuButtonType.RadioButton && e.checkState === Qt.Checked,
            sub: e.hasChildren ? loader(e) : undefined,
            run: e.hasChildren ? undefined : () => e.triggered(),
        }));
    }

    // Openers go a moment after the menu closes (a clicked entry runs after the menu is gone, and
    // needs its opener alive to do it)
    Connections {
        target: Menus
        function onOpenChanged() { if (!Menus.open) cleanup.restart(); else cleanup.stop(); }
    }
    Timer {
        id: cleanup
        interval: 1000
        onTriggered: {
            if (Menus.open) return;
            for (const o of root.openers) o.destroy();
            root.openers = [];
        }
    }

    Component {
        id: openerComp
        QsMenuOpener {
            id: op
            property var done
            property bool sent: false
            // entries arrive over DBus: answer once they've stopped changing for a moment
            onChildrenChanged: op.settle.restart()
            Component.onCompleted: op.settle.restart()
            property Connections watch: Connections {
                target: op.children
                function onValuesChanged() { op.settle.restart(); }
            }
            property Timer settle: Timer {
                interval: 120
                onTriggered: {
                    if (op.sent) return;
                    op.sent = true;
                    op.done(root.convert(op.children.values));
                }
            }
        }
    }

    // qs ipc call tray list | menu <n>   (n = position in the tray, from 0; on the first screen)
    IpcHandler {
        target: "tray"
        function list(): string {
            return SystemTray.items.values.map((it, i) => `${i} ${it.id} ${it.hasMenu ? "menu" : "-"}`).join("\n");
        }
        function menu(n: int): void {
            const it = SystemTray.items.values[n];
            const s = Quickshell.screens[0];
            if (it) root.show(it, s.name, s.width - 300, 48);
        }
    }
}
