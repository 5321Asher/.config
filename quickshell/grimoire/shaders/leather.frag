#version 440
// Leather, drawn rather than tiled: pebbled grain (cells raised in the middle, creased at their
// edges), a slow mottle through the dye, light from above falling off down the piece, and a worn
// sheen along the top edge. Rounded corners. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // px
    vec4 base;          // the dyed leather
    float seed;
    float grain;        // 0 .. 1
    float radius;       // px
    float light;        // 0 .. 1: how much light from above (less on a light theme)
    float scale;        // grain size in px
};

#include "noise.glsl"

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
// distance to the nearest cell centre, and to the edge between the two nearest
vec2 cells(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    float d1 = 8.0, d2 = 8.0;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(float(x), float(y));
            vec2 c = o + 0.15 + 0.7 * hash2(i + o);
            float d = length(c - f);
            if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
        }
    return vec2(d1, d2 - d1);
}

float roundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 s = vec2(seed * 13.0, seed * 7.0);

    vec2 c = cells(px / scale + s);
    float dome = 1.0 - smoothstep(0.0, 0.75, c.x);          // raised middles
    float crease = 1.0 - smoothstep(0.0, 0.12, c.y);        // the creases between
    float mottle = fbm(px / 240.0 + s) - 0.5;
    float fine = hash(floor(px) + s) - 0.5;

    vec3 col = base.rgb;
    col *= 1.0 + grain * (dome * 0.06 - crease * 0.16 + fine * 0.03);
    col *= 1.0 + mottle * 0.12;

    // light from above, falling off; a worn sheen along the top
    float y = qt_TexCoord0.y;
    col *= mix(1.0, 1.08 - 0.22 * y, light);
    col += vec3(1.0) * light * 0.035 * exp(-px.y / 6.0);

    vec2 h = size * 0.5;
    float sd = roundBox(px - h, h, radius);
    float alpha = 1.0 - smoothstep(-0.8, 0.4, sd);
    fragColor = vec4(col * alpha, alpha) * qt_Opacity;
}
