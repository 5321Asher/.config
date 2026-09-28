import QtQuick
import "../theme"

// Text that decodes itself: when `text` changes (or `replay()` is called) the characters run
// through random glyphs for Theme.glitch ms, settling left to right.
Text {
    id: root

    property string target: ""
    property int duration: Theme.glitch
    readonly property string glyphs: "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789/<>#*+=-_"

    text: target
    onTargetChanged: replay()
    function replay() {
        if (!target) { text = ""; return; }
        t0 = Date.now();
        tick.start();
    }
    property real t0: 0
    Timer {
        id: tick
        interval: 30
        repeat: true
        onTriggered: {
            const p = Math.min(1, (Date.now() - root.t0) / root.duration);
            const fixed = Math.floor(p * root.target.length);
            let out = root.target.slice(0, fixed);
            for (let i = fixed; i < root.target.length; i++)
                out += root.target[i] === " " ? " " : root.glyphs[Math.floor(Math.random() * root.glyphs.length)];
            root.text = out;
            if (p >= 1) { root.text = root.target; stop(); }
        }
    }
}
