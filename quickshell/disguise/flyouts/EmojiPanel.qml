import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../widgets"

// Windows 11's emoji panel and clipboard history (Win + . and Win + V): one Acrylic panel with
// Emoji, GIF, Kaomoji, Symbols and Clipboard tabs, opened at the pointer. Picking something types it
// into the app you were in (wtype); a clipboard item is copied back and pasted with Ctrl + V.
// Emoji come from Unicode's list (data/emoji.json, made from emoji-test.txt), recently used first.
// Clipboard history is elephant's (the same one Walker shows): pin, delete, clear all.
Item {
    id: root

    property string screenName
    property bool active: false
    property string tab: "emoji"
    property string query: ""
    property int group: 0

    onActiveChanged: if (active) {
        tab = Flyouts.opts.tab ?? "emoji";
        query = "";
        group = 0;
        if (tab === "clipboard") refresh();
        focusLater.restart();
    }
    onTabChanged: { query = ""; group = 0; if (tab === "clipboard") refresh(); }
    // Win + . while Win + V's panel is open (or the other way round) switches tabs
    Connections {
        target: Flyouts
        function onOptsChanged() { if (root.active && Flyouts.opts.tab) root.tab = Flyouts.opts.tab; }
    }
    Timer { id: focusLater; interval: 30; onTriggered: search.input.forceActiveFocus() }

    // ---------------------------------------------------------------- typing it in
    function insert(text) {
        remember(text);
        Flyouts.close();
        Quickshell.execDetached(["sh", "-c", 'sleep 0.25; wtype -- "$1"', "sh", text]);
    }
    function pasteItem(it) {
        Flyouts.close();
        Quickshell.execDetached(["sh", "-c", 'elephant activate "$1" && sleep 0.3 && wtype -M ctrl v -m ctrl',
                                 "sh", `clipboard;${it.identifier};copy;;`]);
    }

    // ---------------------------------------------------------------- emoji
    property var groups: []
    FileView {
        path: Quickshell.shellDir + "/data/emoji.json"
        onLoaded: { try { root.groups = JSON.parse(text()); } catch (e) { console.warn("emoji.json:", e); } }
    }
    property var recent: []
    FileView {
        id: recentFile
        path: Quickshell.statePath("emoji-recent.json")
        printErrors: false
        onLoaded: { try { root.recent = JSON.parse(text()); } catch (e) {} }
    }
    function remember(ch) {
        const r = [ch].concat(recent.filter(x => x !== ch)).slice(0, 32);
        recent = r;
        recentFile.setText(JSON.stringify(r));
    }
    readonly property var groupIcons: ["😀", "👋", "🐻", "🍔", "🚗", "⚽", "💡", "❤️", "🏳️"]
    readonly property var emojiShown: {
        const q = query.trim().toLowerCase();
        if (q !== "") {
            const out = [];
            for (const g of groups) for (const e of g.emoji) if (e[1].includes(q)) out.push(e[0]);
            return out.slice(0, 300);
        }
        const g = groups[group];
        return g ? g.emoji.map(e => e[0]) : [];
    }

    // ---------------------------------------------------------------- kaomoji and symbols
    readonly property var kaomoji: [
        { name: "Classic ASCII", items: [":)", ":(", ":D", ";)", ":P", ":O", ":|", ":/", "XD", "<3", "^_^", "-_-", "o_O", ">_<", "T_T", "=)", ":3", "B)"] },
        { name: "Greeting", items: ["(＾▽＾)ノ", "ヾ(・ω・*)", "(｡･∀･)ﾉﾞ", "(*・ω・)ﾉ", "( ´ ▽ ` )ﾉ", "(^_^)/", "( ﾟ▽ﾟ)/", "(o´ω`o)ﾉ"] },
        { name: "Happy", items: ["(＾▽＾)", "(*^▽^*)", "(≧▽≦)", "(◕‿◕)", "٩(◕‿◕｡)۶", "(✿◠‿◠)", "ヽ(´▽`)/", "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧", "(*≧ω≦)", "(＾ｖ＾)"] },
        { name: "Love", items: ["(♡˙︶˙♡)", "(´∀｀)♡", "(｡♥‿♥｡)", "♡(ӦｖӦ｡)", "(*˘︶˘*).｡.:*♡", "(っ˘з(˘⌣˘ )", "( ˘ ³˘)♥"] },
        { name: "Sad", items: ["(╥﹏╥)", "(ಥ﹏ಥ)", "(T_T)", "(｡•́︿•̀｡)", "(´；ω；`)", "(っ˘̩╭╮˘̩)っ", "(ノ_<。)"] },
        { name: "Angry", items: ["(╬ಠ益ಠ)", "(ノಠ益ಠ)ノ彡┻━┻", "ヽ(`Д´)ﾉ", "(＃`Д´)", "(╯°□°）╯︵ ┻━┻", "(¬_¬)", "(눈_눈)"] },
        { name: "Surprised", items: ["(⊙_⊙)", "Σ(°△°|||)", "(ﾟДﾟ;)", "(°ロ°) !", "w(°ｏ°)w", "(O_O)", "∑(O_O;)"] },
        { name: "Shrug", items: ["¯\\_(ツ)_/¯", "┐(´ー｀)┌", "ヽ(ー_ー )ノ", "┐('～`;)┌", "¯\\(°_o)/¯"] },
    ]
    readonly property var symbols: [
        { name: "General punctuation", items: "‹›«»‘’“”‚„•·…‰′″‴‼⁇⁈⁉–—―‖†‡§¶©®™℗℠№℮¡¿" },
        { name: "Currency", items: "$¢£¤¥₠₡₢₣₤₥₦₧₨₩₪₫€₭₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿" },
        { name: "Latin symbols", items: "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿŒœŠšŸŽž" },
        { name: "Geometric symbols", items: "■□▢▣▤▥▦▧▨▩▪▫▬▭▮▯▰▱▲△▴▵▶▷▸▹►▻▼▽▾▿◀◁◂◃◄◅◆◇◈◉◊○◌◍◎●◐◑◒◓◔◕" },
        { name: "Math symbols", items: "±×÷∀∁∂∃∄∅∆∇∈∉∊∋∌∍∏∐∑−∓∔∕∖∗∘∙√∛∜∝∞∟∠∡∢∣∤∥∦∧∨∩∪∫∬∭∮≈≠≡≤≥≪≫⊂⊃⊆⊇" },
        { name: "Supplemental symbols", items: "←↑→↓↔↕↖↗↘↙⇐⇑⇒⇓⇔⇕☀☁☂☃☄★☆☎☐☑☒☚☛☜☝☞☟☯☹☺☻♀♂♠♡♢♣♤♥♦♧♩♪♫♬✓✔✕✖✗✘" },
        { name: "Language symbols", items: "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩαβγδεζηθικλμνξοπρστυφχψωАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ" },
    ]
    readonly property var kaomojiShown: {
        const q = query.trim();
        if (q) { let all = []; for (const k of kaomoji) all = all.concat(k.items); return all.filter(x => x.includes(q)); }
        return kaomoji[Math.min(group, kaomoji.length - 1)].items;
    }
    readonly property var symbolsShown: {
        const q = query.trim();
        if (q) { let all = ""; for (const s of symbols) all += s.items; return [...all].filter(x => x === q || x.toLowerCase() === q.toLowerCase()); }
        return [...symbols[Math.min(group, symbols.length - 1)].items];
    }

    // ---------------------------------------------------------------- clipboard
    property var clips: []
    property bool clipsLoaded: false
    function refresh() { clipQuery.running = false; clipQuery.running = true; }
    function pinned(it) { return (it.actions ?? []).includes("unpin"); }
    function clipAct(it, action) {
        clipAct_.command = ["elephant", "activate", `clipboard;${it.identifier};${action};;`];
        clipAct_.running = true;
    }
    Process {
        id: clipQuery
        command: ["elephant", "query", "--json", "clipboard;;200;false"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue;
                    try { out.push(JSON.parse(line).item); } catch (e) {}
                }
                root.clips = out.filter(it => root.pinned(it)).concat(out.filter(it => !root.pinned(it)));
                root.clipsLoaded = true;
            }
        }
    }
    Process { id: clipAct_; onExited: root.refresh() }

    // ---------------------------------------------------------------- look
    Acrylic { anchors.fill: parent }

    // the tabs
    Row {
        id: tabs
        x: 8; y: 8
        spacing: 2
        Repeater {
            model: [
                { k: "emoji", glyph: "", tip: "Emoji" },
                { k: "gif", glyph: "", tip: "GIF" },
                { k: "kaomoji", text: ";-)", tip: "Kaomoji" },
                { k: "symbols", text: "Ω", tip: "Symbols" },
                { k: "clipboard", glyph: "", tip: "Clipboard history" },
            ]
            Btn {
                required property var modelData
                kind: "subtle"
                width: 40; height: 32
                padding: 0
                glyph: modelData.glyph ?? ""
                text: modelData.text ?? ""
                checked: root.tab === modelData.k
                onClicked: root.tab = modelData.k
                // the selected tab's accent underline
                Rectangle {
                    visible: parent.checked
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 16; height: 3; radius: 1.5
                    color: Theme.accent
                }
            }
        }
    }

    Field {
        id: search
        visible: root.tab === "emoji" || root.tab === "kaomoji" || root.tab === "symbols"
        x: 12; y: tabs.y + tabs.height + 8
        width: root.width - 24
        height: visible ? Theme.controlHeight : 0
        glyph: ""
        placeholder: root.tab === "emoji" ? "Search emoji" : root.tab === "kaomoji" ? "Search kaomoji" : "Search symbols"
        text: root.query
        onAccepted: {
            const first = root.tab === "emoji" ? root.emojiShown[0] : root.tab === "kaomoji" ? root.kaomojiShown[0] : root.symbolsShown[0];
            if (first) root.insert(first);
        }
        input.onTextEdited: root.query = input.text
    }

    readonly property real bodyTop: search.y + search.height + 8
    readonly property real bottomBar: (root.tab === "clipboard" || root.tab === "gif" || root.query !== "") ? 0 : 44

    // ---------------------------------------------------------------- Emoji
    Item {
        visible: root.tab === "emoji"
        x: 8; y: root.bodyTop
        width: root.width - 16
        height: root.height - y - root.bottomBar - 4
        Txt {
            id: emojiTitle
            x: 4
            text: root.query !== "" ? (root.emojiShown.length ? "" : "No results") : (root.groups[root.group]?.name ?? "")
            size: Theme.caption; strong: true
            visible: text !== ""
        }
        GridView {
            id: emojiGrid
            y: emojiTitle.visible ? 24 : 0
            width: parent.width
            height: parent.height - y
            cellWidth: Math.floor(width / 8)
            cellHeight: 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.query === "" && root.group === 0 && root.recent.length ? root.recent.concat(["—"]).concat(root.emojiShown) : root.emojiShown
            delegate: Item {
                required property var modelData
                width: emojiGrid.cellWidth; height: emojiGrid.cellHeight
                readonly property bool divider: modelData === "—"
                Rectangle {
                    anchors.fill: parent; anchors.margins: 2
                    radius: Theme.radius
                    visible: !parent.divider
                    color: cellMouse.containsMouse ? Theme.subtle : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    visible: !parent.divider
                    text: modelData
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 22
                }
                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    enabled: !parent.divider
                    hoverEnabled: true
                    onClicked: root.insert(modelData)
                }
            }
        }
    }

    // ---------------------------------------------------------------- GIF
    Column {
        visible: root.tab === "gif"
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 8
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; g: ""; size: 36; color: Theme.text3 }
        Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; strong: true; text: "GIFs aren't available right now" }
        Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; level: 2; size: Theme.caption
              text: "Check your connection and try again later." }
    }

    // ---------------------------------------------------------------- Kaomoji
    GridView {
        id: kaoGrid
        visible: root.tab === "kaomoji"
        x: 8; y: root.bodyTop
        width: root.width - 16
        height: root.height - y - root.bottomBar - 4
        cellWidth: Math.floor(width / 3)
        cellHeight: 40
        clip: true
        model: root.kaomojiShown
        delegate: Item {
            required property var modelData
            width: kaoGrid.cellWidth; height: kaoGrid.cellHeight
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: Theme.radius; color: kaoMouse.containsMouse ? Theme.subtle : "transparent" }
            Txt { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData }
            MouseArea { id: kaoMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.insert(modelData) }
        }
    }

    // ---------------------------------------------------------------- Symbols
    GridView {
        id: symGrid
        visible: root.tab === "symbols"
        x: 8; y: root.bodyTop
        width: root.width - 16
        height: root.height - y - root.bottomBar - 4
        cellWidth: Math.floor(width / 8)
        cellHeight: 40
        clip: true
        model: root.symbolsShown
        delegate: Item {
            required property var modelData
            width: symGrid.cellWidth; height: symGrid.cellHeight
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: Theme.radius; color: symMouse.containsMouse ? Theme.subtle : "transparent" }
            Txt { anchors.centerIn: parent; text: modelData; size: 18 }
            MouseArea { id: symMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.insert(modelData) }
        }
    }

    // the category bar along the bottom (emoji / kaomoji / symbols)
    Row {
        visible: root.bottomBar > 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        x: 8
        spacing: 0
        Repeater {
            model: root.tab === "emoji" ? root.groupIcons.length : root.tab === "kaomoji" ? root.kaomoji.length : root.symbols.length
            Btn {
                id: catBtn
                required property int index
                kind: "subtle"
                width: (root.width - 16) / (root.tab === "emoji" ? root.groupIcons.length : root.tab === "kaomoji" ? root.kaomoji.length : root.symbols.length)
                height: 36
                padding: 0
                checked: root.group === index
                text: root.tab === "emoji" ? "" : root.tab === "kaomoji" ? root.kaomoji[index].items[0] : root.symbols[index].items[0]
                onClicked: root.group = index
                Text {
                    visible: root.tab === "emoji"
                    anchors.centerIn: parent
                    text: root.groupIcons[index] ?? ""
                    font.family: "Noto Color Emoji"; font.pixelSize: 16
                }
                Rectangle {
                    visible: parent.checked
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 16; height: 3; radius: 1.5
                    color: Theme.accent
                }
                Tip { target: catBtn; hovered: catBtn.hovered; text: root.tab === "emoji" ? (root.groups[index]?.name ?? "") : root.tab === "kaomoji" ? root.kaomoji[index].name : root.symbols[index].name }
            }
        }
    }

    // ---------------------------------------------------------------- Clipboard
    Item {
        visible: root.tab === "clipboard"
        x: 12; y: tabs.y + tabs.height + 8
        width: root.width - 24
        height: root.height - y - 8

        Txt { id: clipTitle; text: "Clipboard"; strong: true; size: Theme.bodyLarge - 2 }
        Txt {
            anchors.right: parent.right
            anchors.verticalCenter: clipTitle.verticalCenter
            visible: root.clips.length > 0
            text: "Clear all"
            color: clearMouse.containsMouse ? Theme.accentHover : Theme.accentLink
            MouseArea {
                id: clearMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { const it = root.clips.find(c => !root.pinned(c)); if (it) root.clipAct(it, "remove_all"); }
            }
        }
        Column {
            visible: root.clipsLoaded && root.clips.length === 0
            anchors.centerIn: parent
            width: parent.width
            spacing: 8
            Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; strong: true; text: "You've copied nothing yet" }
            Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; level: 2; size: Theme.caption
                  text: "When you copy something, you'll see your clipboard history here." }
        }
        ListView {
            id: clipList
            y: clipTitle.height + 12
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: root.clips
            delegate: Item {
                id: card
                required property var modelData
                readonly property bool image: modelData.preview_type === "file"
                width: clipList.width
                height: image ? 96 : Math.min(96, body.implicitHeight + 24)
                property bool menuOpen: false

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: cardMouse.containsMouse || card.menuOpen ? Theme.cardHover : Theme.card
                    border.width: 1
                    border.color: Theme.cardStroke
                }
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.pasteItem(card.modelData)
                }
                Txt {
                    id: body
                    visible: !card.image
                    x: 12; y: 12
                    width: parent.width - 60
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: card.modelData.text ?? ""
                }
                Image {
                    visible: card.image
                    x: 12; y: 8
                    width: parent.width - 60; height: parent.height - 16
                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignLeft
                    asynchronous: true
                    sourceSize.height: 160
                    source: card.image ? "file://" + card.modelData.preview : ""
                }
                Glyph {
                    visible: root.pinned(card.modelData)
                    anchors.right: more.left; anchors.rightMargin: 4
                    y: 14
                    g: ""; size: 12; color: Theme.text2
                }
                // "…": Pin / Delete, as on Windows
                Btn {
                    id: more
                    anchors.right: parent.right; anchors.rightMargin: 6
                    y: 6
                    width: 28; height: 28; padding: 0
                    kind: "subtle"
                    glyph: ""
                    glyphSize: 12
                    onClicked: card.menuOpen = !card.menuOpen
                }
                Row {
                    visible: card.menuOpen
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    spacing: 4
                    Btn { id: pinBtn; kind: "subtle"; width: 28; height: 28; padding: 0; glyphSize: 12
                          glyph: root.pinned(card.modelData) ? "" : ""
                          onClicked: { card.menuOpen = false; root.clipAct(card.modelData, root.pinned(card.modelData) ? "unpin" : "pin"); }
                          Tip { target: pinBtn; hovered: pinBtn.hovered; text: root.pinned(card.modelData) ? "Unpin" : "Pin" } }
                    Btn { id: delBtn; kind: "subtle"; width: 28; height: 28; padding: 0; glyphSize: 12; glyph: ""
                          onClicked: { card.menuOpen = false; root.clipAct(card.modelData, "remove"); }
                          Tip { target: delBtn; hovered: delBtn.hovered; text: "Delete" } }
                }
            }
        }
    }
}
