import QtQuick
import QtQuick.Particles
import "../theme"

// Drifting sparks: tiny motes of light that rise, wander and fade (gold and the arcane colour).
// A gentle idle drift from `area` while `running` (rate per second), and burst(x, y, n) for a puff.
Item {
    id: root

    property bool running: true
    property int rate: 6
    property color colorA: Theme.goldBright
    property color colorB: Theme.arcane
    property real size: 7
    property int life: 2600
    // where the idle drift comes from (in this item): a ring by default
    property real ringX: width / 2
    property real ringY: height / 2
    property real ringR: Math.min(width, height) / 2

    function burst(x, y, n) { puffA.burst(Math.ceil(n / 2), x, y); puffB.burst(Math.floor(n / 2), x, y); }

    ParticleSystem { id: sys; running: root.visible }

    ImageParticle {
        system: sys
        groups: ["a"]
        source: Theme.assets + "spark.png"
        color: root.colorA
        colorVariation: 0.08
        alpha: 0.9
        entryEffect: ImageParticle.Fade
    }
    ImageParticle {
        system: sys
        groups: ["b"]
        source: Theme.assets + "spark.png"
        color: root.colorB
        colorVariation: 0.1
        alpha: 0.9
        entryEffect: ImageParticle.Fade
    }

    Emitter {
        system: sys
        group: "a"
        enabled: root.running
        x: root.ringX - root.ringR; y: root.ringY - root.ringR
        width: root.ringR * 2; height: root.ringR * 2
        shape: EllipseShape { fill: false }
        emitRate: root.rate / 2
        lifeSpan: root.life; lifeSpanVariation: root.life / 3
        size: root.size; sizeVariation: root.size / 2; endSize: 1
        velocity: AngleDirection { angle: 270; angleVariation: 40; magnitude: 22; magnitudeVariation: 14 }
    }
    Emitter {
        system: sys
        group: "b"
        enabled: root.running
        x: root.ringX - root.ringR; y: root.ringY - root.ringR
        width: root.ringR * 2; height: root.ringR * 2
        shape: EllipseShape { fill: false }
        emitRate: root.rate / 2
        lifeSpan: root.life; lifeSpanVariation: root.life / 3
        size: root.size; sizeVariation: root.size / 2; endSize: 1
        velocity: AngleDirection { angle: 270; angleVariation: 40; magnitude: 18; magnitudeVariation: 12 }
    }
    // puffs
    Emitter {
        id: puffA
        system: sys; group: "a"; enabled: false
        lifeSpan: 1200; lifeSpanVariation: 500
        size: root.size + 2; sizeVariation: 3; endSize: 1
        velocity: AngleDirection { angle: 0; angleVariation: 180; magnitude: 70; magnitudeVariation: 50 }
    }
    Emitter {
        id: puffB
        system: sys; group: "b"; enabled: false
        lifeSpan: 1300; lifeSpanVariation: 500
        size: root.size + 2; sizeVariation: 3; endSize: 1
        velocity: AngleDirection { angle: 0; angleVariation: 180; magnitude: 60; magnitudeVariation: 40 }
    }
    Wander { system: sys; xVariance: 30; pace: 40 }
    Gravity { system: sys; angle: 270; magnitude: 14 }
}
