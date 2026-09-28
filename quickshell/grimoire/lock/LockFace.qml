import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../theme"
import "../widgets"
import "../spine"

// What the lock looks like: the desk as it was, sinking into candlelit blur, and on it the grimoire,
// closed: a leather cover with a gilt frame and brass corners, its title in blackletter, a strap
// across to the clasp, and on the clasp a lock rune glowing in the arcane colour. Under it, "Speak
// the word": what you type appears as runes on a gilt line (one per letter, never the letter itself).
// A wrong word: the rune flares red, the book shudders, the runes crumble. The right one: the clasp
// flares gold and the cover swings open on its spine, and the desk comes back. The candle burns
// beside the book. Only the main screen gets the word; the others show the book alone.
Item {
    id: root

    property string screenName: ""
    property bool main: true
    property bool preview: false

    property real presence: LockState.revealed ? 1 : 0
    Behavior on presence { NumberAnimation { duration: LockState.revealed ? Theme.lockIntro : Theme.lockOutro; easing.type: Easing.InOutCubic } }
    // the cover opens only on the way out
    readonly property real opening: LockState.leaving ? 1 - presence : 0

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property bool bad: LockState.status === "denied" || LockState.status === "error"
    readonly property bool granted: LockState.status === "granted"

    // ---------------------------------------------------------------- the desk, going under
    Rectangle { anchors.fill: parent; color: Theme.leatherDark }
    Image {
        id: shot
        anchors.fill: parent
        visible: false
        cache: false
        source: root.screenName ? LockState.shotPath(root.screenName) : ""
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blurMax: 80
        blur: 0.8 * root.presence
        brightness: -0.4 * root.presence
        saturation: -0.35 * root.presence
        colorization: 0.25 * root.presence
        colorizationColor: Theme.flame
    }
    // candlelight falling off toward the edges
    Shape {
        anchors.fill: parent
        opacity: root.presence
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width * 0.42; centerY: root.height * 0.62; centerRadius: Math.max(root.width, root.height) * 0.75
                focalX: root.width * 0.42; focalY: root.height * 0.62
                GradientStop { position: 0; color: Theme.alpha(Theme.flame, 0.1) }
                GradientStop { position: 0.4; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha("#000000", 0.7) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // the hour, at the top
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 44 - (1 - root.presence) * 20
        opacity: root.presence
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "h:mm")
            color: Theme.goldBright
            font.family: Theme.uncial
            font.pixelSize: 54
            style: Text.Raised
            styleColor: Qt.alpha("#000000", 0.6)
        }
        Body {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd") + ", the " + Theme.ordinal(clock.date.getDate()) + " of " + Qt.formatDate(clock.date, "MMMM")
            italic: true
            color: Theme.alpha(Theme.fg, 0.8)
            font.pixelSize: 18
        }
    }

    // ---------------------------------------------------------------- the book
    readonly property real bookW: Math.min(560, width * 0.32, (height - 220) / 1.36)
    readonly property real bookH: bookW * 1.36

    Item {
        id: book
        width: root.bookW
        height: root.bookH
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 40 + (1 - root.presence) * (LockState.leaving ? 0 : 60)
        opacity: LockState.leaving ? Math.min(1, root.presence * 3) : root.presence
        scale: LockState.leaving ? 1 + root.opening * 0.08 : 0.94 + 0.06 * root.presence

        // a shudder when the word is wrong
        property real shake: 0
        transform: Translate { x: book.shake }
        SequentialAnimation {
            id: shudder
            NumberAnimation { target: book; property: "shake"; to: -10; duration: 50 }
            NumberAnimation { target: book; property: "shake"; to: 9; duration: 70 }
            NumberAnimation { target: book; property: "shake"; to: -6; duration: 70 }
            NumberAnimation { target: book; property: "shake"; to: 3; duration: 70 }
            NumberAnimation { target: book; property: "shake"; to: 0; duration: 90 }
        }
        Connections {
            target: LockState
            function onAttemptsChanged() { if (LockState.attempts > 0) shudder.restart(); }
        }

        // shadow on the desk
        Rectangle {
            x: 14; y: 20
            width: parent.width; height: parent.height
            radius: 8
            color: Qt.alpha("#000000", 0.6)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
        }
        // the page block, seen at the fore-edge and the foot
        Rectangle {
            x: 8; y: 8
            width: parent.width - 2; height: parent.height - 2
            radius: 4
            color: Theme.pageDeep
            Repeater {
                model: 9
                Rectangle { required property int index; x: parent.width - 7; y: 10 + index; width: 6; height: parent.height - 24; color: "transparent"
                            border.width: 0; Rectangle { x: parent.index % 3; width: 1; height: parent.height; color: Theme.alpha(Theme.ink, 0.12) } }
            }
            Rectangle { x: 10; y: parent.height - 6; width: parent.width - 20; height: 1; color: Theme.alpha(Theme.ink, 0.18) }
            Rectangle { x: 10; y: parent.height - 3; width: parent.width - 20; height: 1; color: Theme.alpha(Theme.ink, 0.12) }
        }
        // the first page, under the cover (seen as it opens)
        Parchment {
            x: 4; y: 3
            width: parent.width - 6; height: parent.height - 6
            radius: 3
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -30
                text: "Welcome back"
                color: Theme.ink
                font.family: Theme.blackletter
                font.pixelSize: root.bookW * 0.1
            }
            GoldRule { anchors.centerIn: parent; anchors.verticalCenterOffset: 14; width: parent.width * 0.5; color: Theme.alpha(Theme.inkDim, 0.7); ornament: "❦" }
        }

        // the cover, hinged at its spine (the left edge)
        Item {
            id: cover
            width: parent.width
            height: parent.height
            transform: Rotation {
                origin.x: 0
                origin.y: cover.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: -165 * root.opening
            }
            // once past edge-on, the inside of the cover faces us
            readonly property bool showingInside: root.opening > 0.52

            Leather {
                anchors.fill: parent
                radius: 6
                visible: !cover.showingInside
                color: Theme.leather
                toolInset: 12
            }
            Rectangle {
                visible: cover.showingInside
                anchors.fill: parent
                radius: 6
                color: Theme.mix(Theme.page, Theme.pageDeep, 0.5)
                border.width: 10
                border.color: Theme.leather
            }

            Item {
                anchors.fill: parent
                visible: !cover.showingInside

                // the spine's edge: a darker band on the left with raised bands
                Rectangle {
                    width: 26; height: parent.height
                    radius: 6
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.darker(Theme.leather, 1.9) }
                        GradientStop { position: 0.7; color: Qt.darker(Theme.leather, 1.2) }
                        GradientStop { position: 1; color: Theme.alpha(Theme.leather, 0) }
                    }
                }
                Repeater {
                    model: 5
                    Rectangle { required property int index; x: 2; y: parent.height * (index + 1) / 6 - 3; width: 18; height: 6; radius: 2
                                color: Qt.lighter(Theme.leather, 1.3); border.width: 1; border.color: Theme.alpha(Theme.gold, 0.6) }
                }

                // the gilt frame and its flourishes
                Rectangle { x: 38; y: 26; width: parent.width - 64; height: parent.height - 52; color: "transparent"; border.width: 2; border.color: Theme.gold }
                Rectangle { x: 45; y: 33; width: parent.width - 78; height: parent.height - 66; color: "transparent"; border.width: 1; border.color: Theme.alpha(Theme.goldDeep, 0.9) }
                Repeater {
                    model: ["tl", "tr", "bl", "br"]
                    Flourish {
                        required property string modelData
                        corner: modelData
                        size: root.bookW * 0.16
                        x: modelData.endsWith("l") ? 50 : cover.width - 31 - width
                        y: modelData.startsWith("t") ? 38 : cover.height - 38 - height
                    }
                }
                // brass corners on the outer edge
                Repeater {
                    model: [[1, 0], [1, 1]]
                    Shape {
                        id: brass
                        required property var modelData
                        width: 30; height: 30
                        x: cover.width - 30
                        y: modelData[1] ? cover.height - 30 : 0
                        ShapePath {
                            strokeColor: Theme.goldDeep
                            strokeWidth: 1
                            fillGradient: LinearGradient { x1: 0; y1: 0; x2: 30; y2: 30
                                GradientStop { position: 0; color: Theme.goldBright } GradientStop { position: 1; color: Theme.goldDeep } }
                            PathSvg { path: brass.modelData[1] ? "M 30 0 L 30 30 L 0 30 Z" : "M 0 0 L 30 0 L 30 30 Z" }
                        }
                    }
                }

                // the title
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 6
                    y: parent.height * 0.13
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Grimoire"
                        color: Theme.goldBright
                        font.family: Theme.blackletter
                        font.pixelSize: root.bookW * 0.17
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.gold; shadowBlur: 0.4; shadowOpacity: 0.55
                                                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 16 }
                    }
                    Caps {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "of " + (LockState.user || "the reader")
                        color: Theme.alpha(Theme.gold, 0.85)
                        font.pixelSize: Math.max(11, root.bookW * 0.032)
                        font.letterSpacing: 3
                    }
                }

                // the strap, from the fore-edge to the clasp
                Rectangle {
                    x: clasp.x + clasp.width / 2
                    y: clasp.y + clasp.height / 2 - 17
                    width: cover.width - x + 6
                    height: 34
                    radius: 3
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(Theme.leatherDark, 1.5) }
                        GradientStop { position: 0.5; color: Theme.leatherDark }
                        GradientStop { position: 1; color: Qt.darker(Theme.leatherDark, 1.4) }
                    }
                    border.width: 1
                    border.color: Qt.alpha("#000000", 0.4)
                    Repeater {
                        model: 2
                        Rectangle { required property int index; x: parent.width - 36 - index * 22; anchors.verticalCenter: parent.verticalCenter
                                    width: 7; height: 7; radius: 3.5; color: Theme.gold; border.width: 1; border.color: Theme.goldDeep }
                    }
                }

                // the clasp and its rune
                Item {
                    id: clasp
                    width: root.bookW * 0.34
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 6
                    y: parent.height * 0.42 - height / 2

                    property real breath: 0
                    SequentialAnimation on breath {
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 2200; easing.type: Easing.InOutSine }
                    }
                    readonly property color runeColor: root.granted ? Theme.goldBright : root.bad ? Theme.danger : Theme.arcane

                    // the brass plate
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        border.width: 2
                        border.color: Theme.goldDeep
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.goldBright }
                            GradientStop { position: 0.5; color: Theme.gold }
                            GradientStop { position: 1; color: Theme.goldDeep }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: parent.width * 0.1
                        radius: width / 2
                        color: Theme.mix(Theme.leatherDark, "#000000", 0.3)
                        border.width: 1
                        border.color: Theme.goldDeep
                    }
                    // a ring of small runes round the inside, turning
                    Item {
                        anchors.fill: parent
                        rotation: clasp.breath * 12 + (LockState.status === "verifying" ? spinner.a : 0)
                        Repeater {
                            model: 16
                            Text {
                                required property int index
                                readonly property real a: index / 16 * 2 * Math.PI
                                x: clasp.width / 2 + Math.cos(a) * clasp.width * 0.33 - width / 2
                                y: clasp.height / 2 + Math.sin(a) * clasp.width * 0.33 - height / 2
                                rotation: index / 16 * 360 + 90
                                text: Theme.allRunes[(index * 7) % Theme.allRunes.length]
                                color: Theme.alpha(clasp.runeColor, 0.55)
                                font.family: Theme.runic
                                font.pixelSize: clasp.width * 0.075
                            }
                        }
                    }
                    // the lock rune
                    Text {
                        anchors.centerIn: parent
                        text: "ᛟ"
                        color: Theme.mix(clasp.runeColor, "#ffffff", 0.2 + clasp.breath * 0.15)
                        font.family: Theme.runic
                        font.pixelSize: clasp.width * 0.36
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: clasp.runeColor
                            shadowBlur: 0.7 + clasp.breath * 0.3
                            shadowOpacity: 0.8 + clasp.breath * 0.2
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                            blurMax: 32
                        }
                    }
                }

                // ---------------------------------------------------------------- speak the word
                Column {
                    visible: root.main
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 6
                    y: clasp.y + clasp.height + parent.height * 0.07
                    width: parent.width * 0.62
                    spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Speak the Word"
                        color: Theme.gold
                        font.family: Theme.decorative
                        font.pixelSize: Math.max(15, root.bookW * 0.05)
                        font.weight: Font.Bold
                    }
                    // the runes, one per letter typed
                    Item {
                        width: parent.width
                        height: 34
                        Row {
                            id: word
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            spacing: 3
                            Repeater {
                                model: Math.min(18, LockState.buffer.length)
                                Text {
                                    id: wr
                                    required property int index
                                    text: Theme.allRunes[(index * 11 + 5) % Theme.allRunes.length]
                                    color: root.bad ? Theme.danger : Theme.mix(Theme.arcane, "#ffffff", 0.3)
                                    font.family: Theme.runic
                                    font.pixelSize: 20
                                    property real born: 0
                                    opacity: born
                                    scale: 1 + (1 - born) * 0.8
                                    NumberAnimation on born { from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                                    layer.enabled: true
                                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.arcane; shadowBlur: 0.6; shadowOpacity: 0.9
                                                                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 12 }
                                }
                            }
                        }
                        // the caret: a quill-stroke of gold
                        Rectangle {
                            visible: LockState.status !== "verifying"
                            x: word.x + word.width + 3
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            width: 2; height: 20
                            color: Theme.gold
                            SequentialAnimation on opacity { loops: Animation.Infinite
                                NumberAnimation { to: 0.1; duration: 600; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine } }
                        }
                    }
                    GoldRule { width: parent.width; color: root.bad ? Theme.danger : Theme.gold; ornament: "◆" }
                    Body {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: LockState.status === "verifying" ? "the clasp considers the word…"
                            : LockState.status === "denied" ? "the word is not known" + (LockState.attempts > 1 ? " (" + LockState.attempts + " tries)" : "")
                            : LockState.status === "error" ? (LockState.detail || "the clasp would not answer · try again")
                            : LockState.status === "granted" ? "the clasp yields"
                            : root.preview ? "a preview · esc closes it" : "the book is closed · enter speaks"
                        italic: true
                        color: root.bad ? Qt.lighter(Theme.danger, 1.3) : Theme.alpha(Theme.fg, 0.7)
                        font.pixelSize: 15
                    }
                }
            }
        }
    }
    QtObject { id: spinner; property real a: 0 }
    NumberAnimation { target: spinner; property: "a"; from: 0; to: 360; duration: 1600; loops: Animation.Infinite; running: LockState.status === "verifying" }

    // ---------------------------------------------------------------- the candle, beside the book
    Candle {
        width: 70
        height: Math.min(420, root.bookH * 0.9)
        x: root.width / 2 - root.bookW / 2 - width - 40
        y: book.y + book.height - height + 20
        opacity: root.presence
    }
    Sparks {
        anchors.fill: parent
        running: root.presence > 0.9
        rate: 4
        ringX: root.width / 2
        ringY: book.y + book.height * 0.42
        ringR: root.bookW * 0.2
        opacity: root.presence
    }
}
