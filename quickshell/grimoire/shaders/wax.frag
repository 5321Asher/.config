#version 440
// A candle's body: a cylinder of wax lit from the front-left, the flame's light glowing down through
// it (strongest just under the flame and at the thin edges, where wax is translucent), faint
// vertical streaks from the dipping, and a soft irregular lip at the top. Premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 wax;
    vec4 flameColor;
    float flicker;       // ~0.8 .. 1.1
    float seed;
};

#include "noise.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    float x = uv.x * 2.0 - 1.0;                       // across the cylinder
    float nz = sqrt(max(0.0, 1.0 - x * x));
    vec3 n = normalize(vec3(x, 0.0, nz));

    // the lip: the top edge dips a little in the middle, unevenly
    float lip = 2.0 + (1.0 - x * x) * 3.0 + (noise(vec2(x * 3.0 + seed * 9.0, seed)) - 0.5) * 3.0;
    float a = smoothstep(lip - 1.0, lip + 0.8, px.y);
    // the sides, antialiased
    a *= smoothstep(1.0, 0.94, abs(x));

    float diff = max(dot(n, normalize(vec3(-0.45, -0.2, 0.9))), 0.0);
    float streak = (noise(vec2(px.x * 0.9 + seed * 5.0, px.y * 0.02)) - 0.5) * 0.06;
    vec3 col = wax.rgb * (0.38 + 0.62 * diff + streak);

    // light through the wax from the flame: deep near the top, more at the thin edges
    float depth = px.y / max(size.x, 1.0);
    float sss = exp(-depth * 0.9) * flicker;
    float rim = pow(abs(x), 2.5);
    col += flameColor.rgb * sss * (0.28 + rim * 0.5);
    // the lip catches the flame's light directly
    col += flameColor.rgb * 0.35 * flicker * (1.0 - smoothstep(lip, lip + 4.0, px.y));
    // a soft specular stripe down the lit side
    col += vec3(1.0) * pow(max(dot(n, normalize(vec3(-0.35, 0.0, 1.0))), 0.0), 40.0) * 0.12;

    fragColor = vec4(col * a, a) * qt_Opacity;
}
