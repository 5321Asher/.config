#version 440
// The edge of a block of pages, seen from the side: hundreds of leaves as fine lines along the
// block (across = 1: lines run along x, stacked down y), not quite even, darker deeper in, with a
// little dust and age. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 paper;
    vec4 ink;
    float across_;       // 1: leaves stacked down y (a foot or head), 0: stacked along x (a fore-edge)
    float seed;
    float shade;         // 0 .. 1: darker toward the far side of the stack
};

#include "noise.glsl"

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 q = across_ > 0.5 ? px : px.yx;           // q.y runs through the stack
    vec2 sz = across_ > 0.5 ? size : size.yx;
    float wob = (noise(vec2(q.x / 60.0, q.y * 0.4) + seed) - 0.5) * 0.9;
    float leaf = fract(q.y * 0.9 + wob);
    float line = smoothstep(0.0, 0.25, leaf) * smoothstep(1.0, 0.7, leaf);
    vec3 col = paper.rgb * (0.86 + 0.14 * line);
    col = mix(col, ink.rgb, (noise(q * vec2(0.03, 1.5) + seed) - 0.5) * 0.08 + 0.04);
    float depth = q.y / max(sz.y, 1.0);
    col *= 1.0 - shade * depth * 0.45;
    // rounded off at the ends
    float ends = smoothstep(0.0, 3.0, q.x) * smoothstep(0.0, 3.0, sz.x - q.x);
    float a = ends;
    fragColor = vec4(col * a, a) * qt_Opacity;
}
