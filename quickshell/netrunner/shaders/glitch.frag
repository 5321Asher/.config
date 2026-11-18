#version 440
// The arrival / departure glitch, as a layer effect over any panel: the picture tears into
// horizontal bands of random height that shift sideways, splits red / cyan at the edges, and
// bands drop out. `amount` 0 = clean, 1 = gone. Premultiplied alpha in and out.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float amount;
    float time;
    float seed;
    vec4 red;
    vec4 cyan;
};
layout(binding = 1) uniform sampler2D source;

#include "noise.glsl"

vec4 at(vec2 p) {
    if (p.x < 0.0 || p.x > 1.0) return vec4(0.0);
    return texture(source, p);
}

void main() {
    float a = clamp(amount, 0.0, 1.0);
    vec2 uv = qt_TexCoord0;
    float t = floor(time * 24.0) + seed * 17.0;          // bands re-roll 24 times a second
    float bandH = 5.0 + 30.0 * hash1(t + 3.1);
    float row = floor(uv.y * size.y / bandH);
    float moves = step(1.0 - a * 0.9, hash(vec2(row, t)));
    float shift = (hash(vec2(row * 1.7, t + 9.0)) - 0.5) * 0.18 * a * moves;
    vec2 p = uv + vec2(shift, 0.0);
    float split = (0.004 + abs(shift) * 0.25) * smoothstep(0.0, 0.15, a);
    vec4 c = at(p);
    vec4 cr = at(p + vec2(split, 0.0));
    vec4 cb = at(p - vec2(split, 0.0));
    vec4 col = vec4(cr.r, c.g, cb.b, max(c.a, max(cr.a, cb.a)));
    col.rgb += red.rgb * max(cr.a - c.a, 0.0) * 0.8 + cyan.rgb * max(cb.a - c.a, 0.0) * 0.8;
    float keep = step(a * 0.85, hash(vec2(row * 2.9, t * 0.7 + 11.0)));
    col *= keep * (1.0 - smoothstep(0.85, 1.0, a));
    fragColor = col * qt_Opacity;
}
