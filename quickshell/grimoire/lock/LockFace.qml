import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import "../theme"
import "../widgets"
import "../spine"

// What the lock looks like: the desk as it was, sinking into candlelit blur, and on it the grimoire,
// closed. It is lit by the candle beside it (widgets/Cover.qml: the cover's rounded, rubbed boards,
// the gilt catching the flame and flickering with it): a gilt frame and flourishes, the title, blind
// tooling on the spine, the page block showing at the fore-edge and foot, a stitched strap across to
// a brass clasp with the lock rune glowing in it. "Speak the Word": what you type appears as quiet
// gold runes (never the letters). A wrong word: the rune turns red and the book gives a small
// shudder. The right one: the clasp flares, the cover swings all the way open on its spine to
// "Welcome back", and only then does the book fade and the desk come back. Only the main screen
// gets the word; the others show the book alone.
Item {
    id: root

    property string screenName: ""
    property bool main: true
    property bool preview: false

    // coming in: 0 -> 1 with the intro; going out, `outro` runs 0 -> 1: the cover opens over its
    // first 60%, then everything fades back to the desk
    property real intro: LockState.revealed ? 1 : 0
    Behavior on intro { enabled: !LockState.leaving; NumberAnimation { duration: Theme.lockIntro; easing.type: Easing.InOutCubic } }
    property real outro: 0
    Connections {
        target: LockState
        function onLeavingChanged() { if (LockState.leaving) outroAnim.restart(); else { outroAnim.stop(); root.outro = 0; } }
    }
    NumberAnimation { id: outroAnim; target: root; property: "outro"; from: 0; to: 1; duration: Theme.lockOutro }
    readonly property real opening: LockState.leaving ? Math.min(1, root.outro / 0.6) : 0
    readonly property real presence: LockState.leaving ? 1 - Math.max(0, (root.outro - 0.6) / 0.4) : intro
    // the cover's swing, eased
    readonly property real swing: opening < 0.5 ? 2 * opening * opening : 1 - Math.pow(-2 * opening + 2, 2) / 2

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
        brightness: -0.45 * root.presence
        saturation: -0.35 * root.presence
        colorization: 0.25 * root.presence
        colorizationColor: Theme.flame
    }
    // candlelight falling off toward the edges, centred on the candle
    Shape {
        anchors.fill: parent
        opacity: root.presence * (0.9 + 0.1 * candle.flicker)
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: candle.x + candle.width / 2; centerY: candle.y + candle.waxTop; centerRadius: Math.max(root.width, root.height) * 0.75
                focalX: centerX; focalY: centerY
                GradientStop { position: 0; color: Theme.alpha(Theme.flame, 0.14) }
                GradientStop { position: 0.35; color: Theme.alpha(Theme.flame, 0.03) }
                GradientStop { position: 1; color: Qt.alpha("#000000", 0.75) }
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
            font.family: Theme.display; font.weight: Font.DemiBold
            font.pixelSize: 58
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
    readonly property real bookW: Math.min(540, width * 0.32, (height - 220) / 1.38)
    readonly property real bookH: bookW * 1.38
    readonly property real thick: Math.max(10, bookW * 0.03)

    Item {
        id: book
        width: root.bookW
        height: root.bookH
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 30
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 40 + (1 - root.intro) * (LockState.leaving ? 0 : 60)
        opacity: root.presence
        scale: LockState.leaving ? 1 + root.swing * 0.04 : 0.95 + 0.05 * root.intro

        // the candle, as the cover sees it (its coordinates): where its flame is
        readonly property vector3d flameAt: Qt.vector3d(candle.x + candle.width / 2 - book.x, candle.y + candle.waxTop - 30 - book.y, root.bookW * 0.55)
        readonly property real flameLight: 1.25 * candle.flicker

        // a shudder when the word is wrong
        property real shake: 0
        transform: Translate { x: book.shake }
        SequentialAnimation {
            id: shudder
            NumberAnimation { target: book; property: "shake"; to: -6; duration: 60 }
            NumberAnimation { target: book; property: "shake"; to: 5; duration: 80 }
            NumberAnimation { target: book; property: "shake"; to: -2; duration: 80 }
            NumberAnimation { target: book; property: "shake"; to: 0; duration: 90 }
        }
        Connections {
            target: LockState
            function onAttemptsChanged() { if (LockState.attempts > 0) shudder.restart(); }
        }

        // shadow on the desk: a soft one thrown away from the candle, and a tight contact shadow
        Rectangle {
            x: 26; y: 30
            width: parent.width + root.thick; height: parent.height + root.thick
            radius: 10
            color: Qt.alpha("#000000", 0.55)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
        }
        Rectangle {
            x: 4; y: 6
            width: parent.width + root.thick; height: parent.height + root.thick
            radius: 6
            color: Qt.alpha("#000000", 0.7)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.5; blurMax: 16 }
        }

        // the back board, under everything
        Cover {
            x: root.thick; y: root.thick
            width: parent.width; height: parent.height
            radius: 7
            color: Qt.darker(Theme.leather, 1.35)
            wear: 0.4
            seed: 0.9
            light: Qt.vector3d(book.flameAt.x - root.thick, book.flameAt.y - root.thick, book.flameAt.z)
            lightPower: book.flameLight * 0.7
        }
        // the page block: the fore-edge and the foot, between the boards
        PageBlock {
            x: parent.width - 6
            y: 8
            width: root.thick
            height: parent.height - 8
            across: false
            shadeDepth: 0.5
        }
        PageBlock {
            x: 10
            y: parent.height - 6
            width: parent.width - 4
            height: root.thick
            across: true
            shadeDepth: 0.5
            seedValue: 0.7
        }

        // the first page, under the cover (seen as it opens)
        Parchment {
            x: 6; y: 4
            width: parent.width - 8; height: parent.height - 8
            radius: 3
            gutter: -1
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
            transform: Hinge { angle: -172 * root.swing; originY: cover.height / 2 }
            // once past edge-on, the inside of the cover faces us
            readonly property bool showingInside: root.swing > 0.5

            // the inside: leather turned in round a marbled-paper pastedown
            Item {
                anchors.fill: parent
                visible: cover.showingInside
                Cover { anchors.fill: parent; radius: 7; color: Qt.darker(Theme.leather, 1.2); wear: 0.3; lightPower: 0.6 }
                Parchment { anchors.fill: parent; anchors.margins: 16; radius: 2; color: Theme.pageDeep; age: 0.6; seed: 0.12 }
            }

            // the outside
            Cover {
                id: face
                anchors.fill: parent
                visible: !cover.showingInside
                radius: 7
                bevel: 12
                wear: 0.75
                seed: 0.41
                light: book.flameAt
                lightPower: book.flameLight

                // blind tooling: the spine's hinge groove and the raised bands along it
                Rectangle { x: 30; width: 3; height: face.height; color: face.blind }
                Repeater {
                    model: 5
                    Rectangle { required property int index; x: 6; y: face.height * (index + 1) / 6 - 1; width: 22; height: 2; color: face.blind }
                }
                // the gilt frame and a blind one inside it
                Rectangle { x: 44; y: 26; width: face.width - 70; height: face.height - 52; color: "transparent"; border.width: 2.5; border.color: face.gilt }
                Rectangle { x: 52; y: 34; width: face.width - 86; height: face.height - 68; color: "transparent"; border.width: 1.5; border.color: face.blind }
                Repeater {
                    model: ["tl", "tr", "bl", "br"]
                    Flourish {
                        required property string modelData
                        corner: modelData
                        size: root.bookW * 0.16
                        color: face.gilt
                        shade: face.gilt
                        stroke: 2
                        x: modelData.endsWith("l") ? 56 : face.width - 38 - width
                        y: modelData.startsWith("t") ? 38 : face.height - 38 - height
                    }
                }
                // the title
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 9
                    y: face.height * 0.12
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Grimoire"
                        color: face.gilt
                        font.family: Theme.blackletter
                        font.pixelSize: root.bookW * 0.17
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ("of " + (LockState.user || "the reader")).toUpperCase()
                        color: face.gilt
                        font.family: Theme.caps
                        font.pixelSize: Math.max(11, root.bookW * 0.032)
                        font.letterSpacing: 3
                    }
                }
                // "Speak the Word", tooled under the clasp
                Text {
                    visible: root.main
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 9
                    y: clasp.y + clasp.height + face.height * 0.06
                    text: "SPEAK THE WORD"
                    color: face.gilt
                    font.family: Theme.caps
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                    font.pixelSize: Math.max(14, root.bookW * 0.042)
                }
            }

            Item {
                anchors.fill: parent
                visible: !cover.showingInside

                // the strap, from the fore-edge to the clasp: leather, stitched along both edges
                Cover {
                    id: strap
                    x: clasp.x + clasp.width / 2
                    y: clasp.y + clasp.height / 2 - height / 2
                    width: cover.width - x + 8
                    height: Math.round(root.bookW * 0.07)
                    radius: 4
                    bevel: 5
                    color: Qt.darker(Theme.leather, 1.5)
                    wear: 0.8
                    seed: 0.77
                    light: Qt.vector3d(book.flameAt.x - x, book.flameAt.y - y, book.flameAt.z)
                    lightPower: book.flameLight
                    Repeater {
                        model: Math.max(0, Math.floor(strap.width / 9))
                        Item {
                            required property int index
                            Rectangle { x: 12 + parent.index * 9; y: 4; width: 5; height: 1.5; color: strap.blind }
                            Rectangle { x: 12 + parent.index * 9; y: strap.height - 5.5; width: 5; height: 1.5; color: strap.blind }
                        }
                    }
                }
                // two brass rivets on it
                Repeater {
                    model: 2
                    Cover {
                        required property int index
                        width: 9; height: 9; radius: 4.5; bevel: 4
                        x: cover.width - 34 - index * 24
                        y: strap.y + strap.height / 2 - 4.5
                        metal: true
                        wear: 0.3
                        light: Qt.vector3d(book.flameAt.x - x, book.flameAt.y - y, book.flameAt.z)
                        lightPower: book.flameLight
                    }
                }

                // brass caps on the fore-edge corners
                Repeater {
                    model: [0, 1]
                    Cover {
                        required property int modelData
                        width: 30; height: 30; radius: 5; bevel: 6
                        x: cover.width - 26
                        y: modelData ? cover.height - 26 : -4
                        metal: true
                        wear: 0.5
                        seed: 0.3 + modelData * 0.2
                        light: Qt.vector3d(book.flameAt.x - x, book.flameAt.y - y, book.flameAt.z)
                        lightPower: book.flameLight
                        Rectangle { x: 11; y: 11; width: 8; height: 8; radius: 4; color: "transparent"; border.width: 1.5; border.color: "#00ff00" }
                    }
                }

                // the clasp: a brass boss with a well in it, a ring of runes pressed round the well
                Cover {
                    id: clasp
                    width: root.bookW * 0.32
                    height: width
                    radius: width / 2
                    bevel: width * 0.12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 9
                    y: parent.height * 0.42 - height / 2
                    metal: true
                    wear: 0.45
                    seed: 0.19
                    light: Qt.vector3d(book.flameAt.x - x, book.flameAt.y - y, book.flameAt.z)
                    lightPower: book.flameLight
                    Rectangle { anchors.fill: parent; anchors.margins: parent.width * 0.16; radius: width / 2; color: "transparent"; border.width: 3; border.color: clasp.blind }
                    Item {
                        anchors.fill: parent
                        Repeater {
                            model: 16
                            Text {
                                required property int index
                                readonly property real a: index / 16 * 2 * Math.PI
                                x: clasp.width / 2 + Math.cos(a) * clasp.width * 0.42 - width / 2
                                y: clasp.height / 2 + Math.sin(a) * clasp.width * 0.42 - height / 2
                                rotation: index / 16 * 360 + 90
                                text: Theme.allRunes[(index * 7) % Theme.allRunes.length]
                                color: clasp.blind
                                font.family: Theme.runic
                                font.pixelSize: clasp.width * 0.065
                            }
                        }
                    }
                }
                // the well: dark, and the lock rune glowing in it
                Rectangle {
                    id: well
                    width: clasp.width * 0.66
                    height: width
                    radius: width / 2
                    anchors.centerIn: clasp
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha("#000000", 0.85) }
                        GradientStop { position: 1; color: Theme.mix(Theme.leatherDark, "#000000", 0.5) }
                    }
                    rotation: LockState.status === "verifying" ? spinner.a : 0
                    readonly property color runeColor: root.granted ? Theme.goldBright : root.bad ? Theme.danger : Theme.arcane
                    property real breath: 0
                    SequentialAnimation on breath {
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 3600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 3600; easing.type: Easing.InOutSine }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "ᛟ"
                        color: Theme.mix(well.runeColor, "#ffffff", 0.2 + well.breath * 0.12)
                        font.family: Theme.runic
                        font.pixelSize: clasp.width * 0.34
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: well.runeColor
                            shadowBlur: 0.6 + well.breath * 0.1
                            shadowOpacity: 0.75 + well.breath * 0.1
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                            blurMax: 32
                        }
                    }
                }

                // ---------------------------------------------------------------- the word
                Column {
                    visible: root.main
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 9
                    y: clasp.y + clasp.height + parent.height * 0.06 + Math.max(14, root.bookW * 0.042) + 16
                    width: parent.width * 0.6
                    spacing: 8
                    // the runes, one per letter typed
                    Item {
                        width: parent.width
                        height: 30
                        Row {
                            id: word
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            spacing: 3
                            Repeater {
                                model: Math.min(18, LockState.buffer.length)
                                Text {
                                    required property int index
                                    text: Theme.allRunes[(index * 11 + 5) % Theme.allRunes.length]
                                    color: root.bad ? Theme.danger : Theme.goldBright
                                    font.family: Theme.runic
                                    font.pixelSize: 20
                                    NumberAnimation on opacity { from: 0; to: 1; duration: 120 }
                                }
                            }
                        }
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
                    GoldRule { width: parent.width; color: root.bad ? Theme.danger : Theme.alpha(Theme.gold, 0.8); ornament: "◆" }
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
        id: candle
        width: 90
        height: Math.min(460, root.bookH * 0.95)
        x: root.width / 2 + 30 - root.bookW / 2 - width - 50
        y: root.height / 2 + 40 + root.bookH / 2 - height + 26
        opacity: root.presence
        large: true
    }
}
