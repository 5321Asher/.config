#version 440
// Behind the summoning circle: a slow swirl of arcane light inside the ring, brightest at the rim,
// with a gold flare that rises as the spell ignites. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float power;         // how charged the circle is: 0 idle .. 1 (letters inscribed)
    float ignite;        // 0 .. 1: the cast
    vec4 arcane;
    vec4 gold;
};

#include "noise.glsl"

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    float t = time;

    // a swirl that turns slowly, faster when charged
    float spin = t * (0.05 + 0.12 * power + 0.9 * ignite);
    vec2 q = vec2(cos(a + spin + r * 2.2), sin(a + spin + r * 2.2)) * (r * 2.2 + 0.5);
    float s = fbm(q * 1.6 + vec2(0.0, -t * 0.12));
    float wisps = smoothstep(0.45, 0.9, s);

    float disk = 1.0 - smoothstep(0.55, 0.9, r);
    float rim = exp(-pow((r - 0.8) / 0.07, 2.0));
    float centre = exp(-r * r * 9.0);

    float strength = 0.10 + 0.22 * power + 0.9 * ignite;
    vec3 col = arcane.rgb * (wisps * disk * strength + rim * (0.25 + 0.4 * power + ignite))
             + gold.rgb * (centre * (0.15 * power + 1.4 * ignite) + rim * ignite * 0.8);
    float alpha = clamp(wisps * disk * strength + rim * (0.2 + 0.35 * power + ignite) + centre * (0.12 * power + ignite), 0.0, 1.0);
    // fade out beyond the rim
    float edge = 1.0 - smoothstep(0.86, 1.0, r);
    fragColor = vec4(col * edge, alpha * edge) * qt_Opacity;
}
