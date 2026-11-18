#version 440
// The subnet map's network scan: a ring sweeping out from `origin` (pixels) to `radius`, a hex grid
// lit in the band just behind its edge, faint echo rings following, and the screen darkened inside
// it (`dim`). Contracting (closing) is the same with the radius going back down.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec2 origin;
    float radius;
    float dim;
    float time;
    vec4 ring;
    vec4 grid;
    vec4 base;
};

float hexDist(vec2 p) { p = abs(p); return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x); }

void main() {
    vec2 px = qt_TexCoord0 * size;
    float d = length(px - origin);
    float inside = 1.0 - smoothstep(radius - 2.0, radius, d);

    // the hex grid, lit in a band behind the edge
    vec2 g = px / 30.0;
    const vec2 r = vec2(1.0, 1.7320508);
    vec2 ha = mod(g, r) - r * 0.5;
    vec2 hb = mod(g - r * 0.5, r) - r * 0.5;
    vec2 gv = dot(ha, ha) < dot(hb, hb) ? ha : hb;
    float seam = 1.0 - smoothstep(0.0, 0.05, 0.5 - hexDist(gv));
    float band = smoothstep(radius - 260.0, radius - 10.0, d) * inside;

    float edge = exp(-pow((d - radius) / 5.0, 2.0)) * step(1.0, radius);
    float halo = exp(-pow((d - radius) / 40.0, 2.0)) * 0.35 * step(1.0, radius);
    float echo = 0.0;
    for (int i = 1; i <= 3; i++) {
        float er = radius - float(i) * 90.0;
        echo += exp(-pow((d - er) / 2.5, 2.0)) * (0.5 / float(i)) * step(0.0, er);
    }

    vec4 col = vec4(base.rgb, 1.0) * dim * inside;
    col += vec4(grid.rgb, 1.0) * seam * band * 0.45;
    col += vec4(ring.rgb, 1.0) * (edge * 1.2 + halo + echo * 0.7);
    fragColor = col * qt_Opacity;
}
