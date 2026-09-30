#version 440
// Parchment, drawn rather than tiled: the page colour with a slow, large wash of tone, fine laid
// fibres running in two directions, a whisper of grain, margins browned with age, and (for a page
// in an open book) the gutter's shade where the leaf curves down into the binding, with the soft
// highlight of the curve beside it. Rounded corners with a hairline edge. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // px
    vec4 base;          // the page
    vec4 deep;          // its darker, older tone
    vec4 ink;           // for the edge and the age
    float seed;
    float age;          // 0 .. 1: browning at the margins
    float gutter;       // -1: binding on the left, 1: on the right, 0: a loose sheet
    float radius;       // px
    float grain;        // 0 .. 1
    float edge;         // 0 / 1: the hairline edge
};

#include "noise.glsl"

float roundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 s = vec2(seed * 17.0, seed * 31.0);

    // a slow wash of tone, never blotchy
    float wash = fbm(px / 420.0 + s);
    vec3 col = mix(base.rgb, deep.rgb, smoothstep(0.35, 0.8, wash) * 0.32);

    // laid fibres: fine streaks in two directions, and the odd longer fibre
    vec2 r1 = mat2(0.96, 0.28, -0.28, 0.96) * px;
    vec2 r2 = mat2(0.87, -0.5, 0.5, 0.87) * px;
    float f1 = noise(vec2(r1.x / 1.6, r1.y / 9.0) + s);
    float f2 = noise(vec2(r2.x / 1.3, r2.y / 11.0) + s * 1.7);
    float fib = (f1 - 0.5) * 0.55 + (f2 - 0.5) * 0.45;
    float longf = smoothstep(0.82, 0.97, noise(vec2(r1.x / 2.2, r1.y / 90.0) + s * 2.3));
    float g = hash(floor(px) + s) - 0.5;
    col *= 1.0 + grain * (fib * 0.04 + g * 0.03);
    col = mix(col, deep.rgb * 0.92, longf * grain * 0.18);

    // age at the margins, a ragged front of it
    float d = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
    float ragged = fbm(px / 60.0 + s * 3.0) * 38.0;
    float browned = 1.0 - smoothstep(0.0, 70.0 + ragged, d);
    col = mix(col, mix(deep.rgb, ink.rgb, 0.18), browned * age * 0.55);

    // the gutter: shade into the binding, a soft highlight on the curve just beside it
    if (abs(gutter) > 0.5) {
        float gx = gutter > 0.0 ? size.x - px.x : px.x;
        float shade = exp(-gx / 26.0) * 0.42 + exp(-gx / 110.0) * 0.12;
        float lift = exp(-pow((gx - 70.0) / 55.0, 2.0)) * 0.035;
        col = col * (1.0 - shade) + lift;
    }

    // the sheet's outline, a hairline just inside it
    vec2 half_ = size * 0.5;
    float sd = roundBox(px - half_, half_, radius);
    float alpha = 1.0 - smoothstep(-0.8, 0.4, sd);
    float line = (1.0 - smoothstep(0.0, 1.2, abs(sd + 1.0))) * edge;
    col = mix(col, mix(deep.rgb, ink.rgb, 0.35), line * 0.7);

    fragColor = vec4(col * alpha, alpha) * qt_Opacity;
}
