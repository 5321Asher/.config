pragma Singleton

import QtQuick
import Quickshell
import "../theme"

// Pomodoro + countdown timer. Lives outside the panel so it keeps running when it's closed.
Singleton {
    id: root

    // "pomodoro" or "timer"
    property string mode: "pomodoro"

    // Pomodoro settings (minutes)
    property int focusMins: 25
    property int shortMins: 5
    property int longMins: 15
    // Focus sessions before a long break
    property int rounds: 4
    // Start the next phase automatically
    property bool autoStart: false

    // Pomodoro state: "focus", "short" or "long"
    property string phase: "focus"
    // Focus sessions finished in the current set
    property int completed: 0

    // Countdown timer setting (minutes)
    property int timerMins: 10

    property int duration: focusMins * 60
    property int remaining: duration
    property bool running: false
    property real endsAt: 0

    readonly property bool active: running || remaining < duration
    readonly property real progress: duration > 0 ? remaining / duration : 0
    readonly property string remainingText: {
        const m = Math.floor(remaining / 60), s = remaining % 60;
        return (m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") : m) + ":" + String(s).padStart(2, "0");
    }
    readonly property string phaseLabel: mode === "timer" ? "Timer"
        : phase === "focus" ? "Focus" : phase === "short" ? "Short break" : "Long break"

    function phaseMins(p) {
        return p === "focus" ? focusMins : p === "short" ? shortMins : longMins;
    }

    function load(secs) {
        running = false;
        duration = secs;
        remaining = secs;
    }

    function start() {
        if (remaining <= 0)
            remaining = duration;
        endsAt = Date.now() + remaining * 1000;
        running = true;
    }

    function pause() {
        tick();
        running = false;
    }

    function toggle() {
        running ? pause() : start();
    }

    function reset() {
        load(mode === "timer" ? timerMins * 60 : phaseMins(phase) * 60);
    }

    function setMode(m) {
        if (m === mode)
            return;
        mode = m;
        if (m === "pomodoro") {
            phase = "focus";
            completed = 0;
        }
        reset();
    }

    function setTimerMins(m) {
        timerMins = Math.max(1, Math.min(600, m));
        if (mode === "timer" && !running)
            reset();
    }

    // Change a pomodoro length; applies right away if that phase is loaded and untouched
    function setPhaseMins(p, m) {
        m = Math.max(1, Math.min(180, m));
        if (p === "focus") focusMins = m;
        else if (p === "short") shortMins = m;
        else longMins = m;
        if (mode === "pomodoro" && phase === p && !active)
            reset();
    }

    // Jump to the next pomodoro phase (or restart the timer)
    function skip() {
        if (mode === "timer") {
            reset();
            return;
        }
        if (phase === "focus") {
            completed++;
            phase = completed >= rounds ? "long" : "short";
        } else {
            if (phase === "long")
                completed = 0;
            phase = "focus";
        }
        reset();
    }

    function tick() {
        if (!running)
            return;
        remaining = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));
        if (remaining === 0)
            finish();
    }

    function finish() {
        running = false;
        Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]);

        if (mode === "timer") {
            notify("Timer done", timerMins + " minute timer finished");
            reset();
            return;
        }

        const was = phase;
        skip();
        if (was === "focus")
            notify("Focus session done", "Time for a " + phaseMins(phase) + " minute " + (phase === "long" ? "long break" : "break"));
        else
            notify("Break's over", "Back to focus for " + focusMins + " minutes");
        if (autoStart)
            start();
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Focus", "-i", "alarm-symbolic", title, body]);
    }

    Timer {
        running: root.running
        repeat: true
        interval: 250
        onTriggered: root.tick()
    }
}
