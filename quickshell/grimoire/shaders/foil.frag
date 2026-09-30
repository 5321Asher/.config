#version 440
// Gold foil: whatever is white in the source (the card's linework) comes out as stamped gold leaf,
// brushed, deeper in its recesses, with a band of light that follows the pointer across the card.
// Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 light;          // where the light is, in 0..1 over the card
    float shine;         // 0 .. 1: how strongly it catches the light
    vec4 gold;
    vec4 goldBright;
    vec4 goldDeep;
};
layout(binding = 1) uniform sampler2D source;

#include "noise.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    float m = texture(source, uv).a;
    if (m < 0.003) { fragColor = vec4(0.0); return; }

    // brushed: fine streaks across, and a slow wave of tone
    float brush = noise(vec2(uv.x * 900.0, uv.y * 7.0)) - 0.5;
    float tone = fbm(uv * 3.0);
    vec3 col = mix(goldDeep.rgb, gold.rgb, smoothstep(0.25, 0.75, tone + (uv.y - 0.5) * -0.3));
    col *= 1.0 + brush * 0.12;

    // the band of light, running diagonally through the pointer
    vec2 d = uv - light;
    float band = dot(d, normalize(vec2(1.0, -0.65)));
    float spec = exp(-band * band / 0.012) * (0.35 + 0.65 * shine);
    float glint = exp(-dot(d, d) / 0.02) * shine;
    col = mix(col, goldBright.rgb, clamp(spec * 0.8 + glint * 0.5, 0.0, 1.0));

    fragColor = vec4(col * m, m) * qt_Opacity;
}
