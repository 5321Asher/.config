import QtQuick

// A clock for intros and outros that always plays through. It advances by the frame time capped at
// 1/30 s, so a stalled frame (a window mapping, a Loader building) slows it down for a moment
// instead of skipping most of the animation. `ms` counts from play() and stops at `until`.
FrameAnimation {
    id: root

    property real ms: 0
    property real until: 1e9

    function play() { ms = 0; if (!running) start(); }
    onTriggered: {
        ms = Math.min(until, ms + Math.min(frameTime, 1 / 30) * 1000);
        if (ms >= until) stop();
    }
}
