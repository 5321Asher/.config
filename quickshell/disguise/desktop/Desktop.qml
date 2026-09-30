import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"
import "../widgets"
import "../flyouts"
import "../settings"

// The desktop, as Windows 11 has it: a layer over the wallpaper and under the windows, so it only
// hears clicks on bare desktop. The Recycle Bin and whatever is in ~/Desktop as icons in a column
// from the top left (on the first screen); click selects, double-click opens, right-click an icon
// for its menu. Right-click anywhere else: View, Sort by, Refresh, New (folder, text document),
// Display settings, Personalize, Open in Terminal.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    readonly property bool icons: modelData === Quickshell.screens[0]

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "disguise-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string desk: Quickshell.env("HOME") + "/Desktop"
    readonly property string trash: Quickshell.env("HOME") + "/.local/share/Trash/files"

    // View / Sort by (kept for the session, as a Windows user would expect them to stick)
    property int iconSize: 48               // large 96, medium 48, small 32
    property bool showIcons: true
    property string sortBy: "name"          // name | size | type | date
    property string selected: ""

    // ~/Desktop may not exist (it's made by New → Folder): a model pointed at a missing folder lists
    // its parent instead, so it only looks once the folder is there
    property bool deskExists: false
    Process {
        id: deskCheck
        running: true
        command: ["test", "-d", root.desk]
        onExited: code => root.deskExists = code === 0
    }
    Timer { interval: 3000; running: !root.deskExists; repeat: true; onTriggered: deskCheck.running = true }
    FolderListModel {
        id: files
        folder: root.deskExists ? "file://" + root.desk : "" 
        showDirsFirst: true
        showHidden: false
        sortField: root.sortBy === "size" ? FolderListModel.Size : root.sortBy === "type" ? FolderListModel.Type
                 : root.sortBy === "date" ? FolderListModel.Time : FolderListModel.Name
    }
    FolderListModel {
        id: trashFiles
        folder: "file://" + root.trash
        showHidden: true
        showDirs: true
    }

    // everything shown: [{ key, name, icon, path, bin }]
    readonly property var items: {
        const out = [{ key: "bin", name: "Recycle Bin", icon: trashFiles.count > 0 ? "user-trash-full" : "user-trash", bin: true }];
        for (let i = 0; root.deskExists && i < files.count; i++) {
            const p = files.get(i, "filePath"), n = files.get(i, "fileName"), dir = files.get(i, "fileIsDir");
            out.push({ key: p, name: n, path: p, icon: dir ? "folder" : iconFor(n) });
        }
        return out;
    }
    function iconFor(n) {
        const ext = (n.split(".").pop() ?? "").toLowerCase();
        if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"].includes(ext)) return "image-x-generic";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext)) return "video-x-generic";
        if (["mp3", "flac", "ogg", "wav", "m4a"].includes(ext)) return "audio-x-generic";
        if (["txt", "md", "log"].includes(ext)) return "text-x-generic";
        if (["pdf"].includes(ext)) return "application-pdf";
        if (["zip", "tar", "gz", "xz", "7z", "rar"].includes(ext)) return "package-x-generic";
        if (ext === "desktop") return "application-x-executable";
        return "text-x-generic";
    }

    function open(it) {
        if (it.bin) Quickshell.execDetached(["thunar", "trash:///"]);
        else Quickshell.execDetached(["xdg-open", it.path]);
    }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function newName(base, ext) {
        return `n="${base}"; i=2; while [ -e "$HOME/Desktop/$n${ext}" ]; do n="${base} ($i)"; i=$((i+1)); done; echo "$n${ext}"`;
    }

    function deskMenu(x, y) {
        Flyouts.menu(root.modelData.name, [
            { text: "View", glyph: "", sub: [
                { text: "Large icons", radio: root.iconSize === 96, run: () => root.iconSize = 96 },
                { text: "Medium icons", radio: root.iconSize === 48, run: () => root.iconSize = 48 },
                { text: "Small icons", radio: root.iconSize === 32, run: () => root.iconSize = 32 },
                { sep: true },
                { text: "Show desktop icons", check: root.showIcons, run: () => root.showIcons = !root.showIcons },
            ] },
            { text: "Sort by", glyph: "", sub: [
                { text: "Name", radio: root.sortBy === "name", run: () => root.sortBy = "name" },
                { text: "Size", radio: root.sortBy === "size", run: () => root.sortBy = "size" },
                { text: "Item type", radio: root.sortBy === "type", run: () => root.sortBy = "type" },
                { text: "Date modified", radio: root.sortBy === "date", run: () => root.sortBy = "date" },
            ] },
            { text: "Refresh", glyph: "", run: () => { deskCheck.running = true; files.folder = ""; files.folder = root.deskExists ? "file://" + root.desk : ""; } },
            { sep: true },
            { text: "New", glyph: "", sub: [
                { text: "Folder", glyph: "", run: () => root.run(`mkdir -p "$HOME/Desktop" && cd "$HOME/Desktop" && mkdir "$(${root.newName("New folder", "")})"`) },
                { text: "Text Document", glyph: "", run: () => root.run(`mkdir -p "$HOME/Desktop" && cd "$HOME/Desktop" && touch "$(${root.newName("New Text Document", ".txt")})"`) },
            ] },
            { sep: true },
            { text: "Display settings", glyph: "", run: () => SettingsApp.open("display") },
            { text: "Personalize", glyph: "", run: () => SettingsApp.open("personalization") },
            { sep: true },
            { text: "Open in Terminal", glyph: "", run: () => root.run(`mkdir -p "$HOME/Desktop"; kitty --directory "$HOME/Desktop"`) },
        ], x, y, false);
    }
    function itemMenu(it, x, y) {
        if (it.bin) {
            Flyouts.menu(root.modelData.name, [
                { text: "Open", glyph: "", run: () => root.open(it) },
                { text: "Empty Recycle Bin", glyph: "", enabled: trashFiles.count > 0,
                  run: () => root.run(`rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/files/".[!.]* "$HOME/.local/share/Trash/info/"*`) },
            ], x, y, false);
            return;
        }
        Flyouts.menu(root.modelData.name, [
            { text: "Open", glyph: "", run: () => root.open(it) },
            { text: "Open file location", glyph: "", run: () => Quickshell.execDetached(["thunar", root.desk]) },
            { sep: true },
            { text: "Copy as path", glyph: "", run: () => Quickshell.execDetached(["wl-copy", it.path]) },
            { text: "Delete", glyph: "", run: () => Quickshell.execDetached(["gio", "trash", it.path]) },
        ], x, y, false);
    }

    // bare desktop: left click clears the selection, right click the desktop menu
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => { root.selected = ""; if (m.button === Qt.RightButton) root.deskMenu(m.x, m.y); }
    }

    // the icons, down the left then across, as Windows lays them out
    Grid {
        visible: root.icons && root.showIcons
        x: 4; y: 4
        flow: Grid.TopToBottom
        rows: Math.max(1, Math.floor((root.height - Theme.taskbarHeight - 8) / (root.iconSize + 52)))
        spacing: 2
        Repeater {
            model: root.items
            Item {
                id: icon
                required property var modelData
                readonly property bool sel: root.selected === modelData.key
                width: Math.max(76, root.iconSize + 28)
                height: root.iconSize + 50
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: icon.sel ? Qt.alpha("#cce8ff", 0.4) : iconMouse.containsMouse ? Qt.alpha("#ffffff", 0.18) : "transparent"
                    border.width: icon.sel ? 1 : 0
                    border.color: Qt.alpha("#99d1ff", 0.9)
                }
                AppIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    size: root.iconSize
                    name: icon.modelData.icon
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.iconSize + 8
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: icon.modelData.name
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: Qt.alpha("#000000", 0.45)
                    font.family: Theme.font
                    font.pixelSize: Theme.caption
                }
                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        root.selected = icon.modelData.key;
                        if (m.button === Qt.RightButton) {
                            const p = mapToItem(null, m.x, m.y);
                            root.itemMenu(icon.modelData, p.x, p.y);
                        }
                    }
                    onDoubleClicked: m => { if (m.button === Qt.LeftButton) root.open(icon.modelData); }
                }
            }
        }
    }
}
