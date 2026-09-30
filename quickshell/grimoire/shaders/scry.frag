#version 440
// The scrying glass: a disc of black glass, deep at its rim, with a mist of arcane light turning
// slowly inside it (stirred a little when you write), the window's reflection as a soft arc of light
// at the top left, and a gold flare in the heart when a program is summoned. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float stir;          // 0 .. 1
    float flare;         // 0 .. 1
    float px;            // the disc's diameter in px (for antialiasing)
    vec4 arcane;
    vec4 gold;
    vec4 glass;
};

#include "noise.glsl"

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float r = length(p);
    float a = 1.0 - smoothstep(1.0 - 2.0 / px, 1.0, r);
    if (a <= 0.0) { fragColor = vec4(0.0); return; }

    float ang = atan(p.y, p.x);
    float t = time * (0.05 + 0.1 * stir);
    vec2 q = vec2(cos(ang + t + r * 1.8), sin(ang + t + r * 1.8)) * (r * 1.7 + 0.4);
    float mist = fbm(q * 1.4 + vec2(time * 0.03, -time * 0.05));
    mist = smoothstep(0.4, 0.95, mist) * (1.0 - smoothstep(0.55, 1.0, r) * 0.6);

    vec3 col = glass.rgb * (1.0 - r * r * 0.55);
    col += arcane.rgb * mist * (0.22 + 0.25 * stir);
    col += gold.rgb * exp(-r * r * 5.0) * flare * 1.2;
    // the depth at the rim
    col *= 1.0 - smoothstep(0.75, 1.0, r) * 0.5;
    // the reflection: a soft crescent up and to the left
    vec2 h = p - vec2(-0.25, -0.35);
    float refl = exp(-pow((length(h) - 0.55) / 0.06, 2.0)) * smoothstep(0.2, -0.6, p.x + p.y);
    col += vec3(1.0) * refl * 0.1;

    fragColor = vec4(col * a, a) * qt_Opacity;
}
