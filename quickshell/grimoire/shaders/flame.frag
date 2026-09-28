#version 440
// The candle's flame: a teardrop that sways and stretches with the draught, a white-gold core, the
// theme's flame colour round it, a blue root at the wick and a soft halo. `time` runs forever.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float seed;
    float glow;          // halo strength, 0..1
    float gutter;        // 0 = steady, 1 = guttering (lower, redder, jumpier)
    vec4 flameColor;
};

#include "noise.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    // p.x: -1..1 across, h: 0 at the bottom of the item, 1 at the top
    vec2 p = vec2((uv.x - 0.5) * 2.0, 1.0 - uv.y);
    float t = time + seed * 17.0;
    float h = p.y;

    // the draught: a slow lean plus quick trembles, more at the tip
    float lean = (noise(vec2(t * 0.7, seed)) - 0.5) * 0.5 + (noise(vec2(t * 3.1, 7.0 + seed)) - 0.5) * 0.18 * (1.0 + gutter);
    // flame body lives in the lower 60% of the item (the halo gets the rest)
    float base = 0.10, tall = 0.52 * (0.86 + 0.14 * noise(vec2(t * 5.3, 3.0 + seed))) * (1.0 - 0.25 * gutter);
    float y = (h - base) / tall;                       // 0 at the wick, 1 at the tip
    float bend = lean * max(y, 0.0) * max(y, 0.0) * 0.55;
    float turb = (fbm(vec2(p.x * 2.5 + seed, h * 5.0 - t * 2.6)) - 0.5) * 0.16 * clamp(y, 0.0, 1.0);
    float x = p.x - bend + turb;

    // the teardrop's half-width at this height (in the -1..1 space)
    float yc = clamp(y, 0.0, 1.0);
    float w = 0.34 * pow(yc, 0.42) * pow(1.0 - yc, 0.75) * 1.9;
    float d = abs(x) / max(w, 1e-4);                   // 0 on the axis, 1 at the edge
    float inside = (y > 0.0 && y < 1.0) ? 1.0 - smoothstep(0.62, 1.0, d) : 0.0;

    vec3 flame = flameColor.rgb;
    float core = (1.0 - smoothstep(0.0, 0.62, d)) * (1.0 - smoothstep(0.08, 0.62, y));
    vec3 col = mix(flame, vec3(1.0, 0.97, 0.86), core);
    col = mix(col, flame * vec3(1.0, 0.5, 0.3), smoothstep(0.5, 1.0, y) * (0.55 + 0.3 * gutter));
    float root = (1.0 - smoothstep(0.0, 0.2, y)) * smoothstep(0.15, 0.95, d);
    col = mix(col, vec3(0.32, 0.42, 1.0), root * 0.75);
    float a = inside * (0.78 + 0.22 * core) * (1.0 - smoothstep(0.82, 1.0, y) * 0.6);

    // the halo round it, breathing with the flame
    vec2 g = vec2(p.x - lean * 0.2, (h - base - tall * 0.42) * 1.25);
    float breathe = 0.85 + 0.15 * noise(vec2(t * 2.0, 11.0 + seed));
    float halo = exp(-dot(g, g) * 5.5) * 0.42 * glow * breathe;

    vec3 rgb = col * a + flame * halo * (1.0 - a);
    float alpha = a + halo * (1.0 - a);
    fragColor = vec4(rgb, alpha) * qt_Opacity;
}
